/**
 * The module for boot-strapping. The kernel is expected to run in "container zero", i.e. the
 * initial container within the server process. As such, it will be the only container with access
 * to all of the "unrestricted" OS capabilities via injection. Its purpose is to provide maximally
 * restricted forms of those injectable resources to each of its sub-containers (each of which
 * represent specific system services), such that each system service has exactly the capabilities
 * that it requires, and no more. Furthermore, the kernel is responsible for introducing system
 * services to each other, by injecting "common" interfaces into dependent system services, with
 * those interfaces coming from the systems services that are depended on; as with the OS
 * capabilities, the minimally required set of maximally restricted interfaces are injected.
 */
module kernel.xqiz.it {
    package auth   import webauth.xtclang.org;
    package crypto import crypto.xtclang.org;
    package json   import json.xtclang.org;
    package jsondb import jsondb.xtclang.org;
    package oodb   import oodb.xtclang.org;
    package net    import net.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    package common      import common.xqiz.it;
    package platformDB  import platformDB.xqiz.it;

    import ecstasy.mgmt.Container;
    import ecstasy.mgmt.ModuleRepository;

    import ecstasy.reflect.ModuleTemplate;

    import auth.Configuration;
    import auth.DBRealm;

    import common.ErrorLog;
    import common.HostManager;

    import common.names;
    import common.utils;

    import platformDB.Connection;

    import crypto.Algorithms;
    import crypto.CertificateManager;
    import crypto.CryptoKey;
    import crypto.Decryptor;
    import crypto.KeyStore;

    import json.Doc;
    import json.Parser;

    import net.IPAddress;

    import web.http.HostInfo;

    import xenia.HttpServer;

    void run(String[] args=[]) {
        @Inject Console          console;
        @Inject Directory        homeDir;
        @Inject ModuleRepository repository;

        // get the password
        String password = args.size == 0
                ? console.readLine("Enter password:", suppressEcho=True)
                : args[0];

        // ensure necessary directories
        Directory platformDir = homeDir.dirFor("xqiz.it/platform").ensure();
        Directory accountsDir = homeDir.dirFor("xqiz.it/accounts").ensure();
        Directory buildDir    = platformDir.dirFor("build").ensure();
        Directory hostDir     = platformDir.dirFor("host").ensure();

        // get the configuration
        Map<String, Doc> config;
        try {
            File   configFile = platformDir.fileFor("cfg.json");
            File   configInit = /cfg.json;
            String jsonConfig;
            if (configFile.exists && configFile.modified > configInit.modified) {
                jsonConfig = configFile.contents.unpackUtf8();
            } else {
                if (configFile.exists) {
                    console.print($"Warning: Your local config file is out of date; replacing with the default");
                }
                immutable Byte[] configData = configInit.contents;
                jsonConfig = configData.unpackUtf8();
                configFile.contents = configData; // create a copy from the embedded resource
            }

            config = new Parser(jsonConfig.toReader()).parseDoc().as(Map<String, Doc>);
        } catch (Exception e) {
            console.print($"Error: Invalid config file");
            return;
        }

        ErrorLog errors = new ErrorLog();
        try {
            String      hostName  = config.getOrDefault("hostName",  names.PlatformUri).as(String);
            UInt16      httpPort  = config.getOrDefault("httpPort",  8080).as(IntLiteral).toUInt16();
            UInt16      httpsPort = config.getOrDefault("httpsPort", 8090).as(IntLiteral).toUInt16();
            IPAddress[] proxies   = config.getOrDefault("proxies",   [])  .as(Doc[])
                                          .map(addr -> new IPAddress(addr.as(String))).toArray();

            File storeFile = platformDir.fileFor(names.PlatformKeyStore);
            if (storeFile.exists) {
                // check if both cookie and password encryption keys exist
                @Inject(opts=new KeyStore.Info(storeFile.contents, password)) KeyStore keystore;
                Boolean cookieKey   = keystore.getKey(names.CookieEncryptionKey);
                Boolean passwordKey = keystore.getKey(names.PasswordEncryptionKey);
                if (!cookieKey || !passwordKey) {
                    @Inject CertificateManager manager;
                    if (!cookieKey) {
                        manager.createSymmetricKey(storeFile, password, names.CookieEncryptionKey);
                    }
                    if (!passwordKey) {
                        manager.createSymmetricKey(storeFile, password, names.PasswordEncryptionKey);
                    }
                }
            } else {
                console.print($|Warning: *** The platform keystore does not exist; creating a new one\
                               | with a self-signed certificate for the platform web server.
                               |Warning: *** The password you have provided will be used to encrypt it.
                             );

                @Inject CertificateManager manager;
                String dName = CertificateManager.distinguishedName(hostName, org="localhost", orgUnit="Platform");

                manager.createCertificate(storeFile, password, names.PlatformTlsKey, dName);
                manager.createSymmetricKey(storeFile, password, names.CookieEncryptionKey);
                manager.createSymmetricKey(storeFile, password, names.PasswordEncryptionKey);
                }

            // initialize the account manager; it's inside the kernel for now, but we need to
            // consider creating a separate container for it
            console.print($"Info: Starting the AccountManager...");

            @Inject(opts=new KeyStore.Info(storeFile.contents, password)) KeyStore keystore;
            assert CryptoKey key := keystore.getKey(names.PasswordEncryptionKey) as
                                    $"Key {names.PasswordEncryptionKey} is missing in the keystore";

            @Inject Algorithms algorithms;
            assert Decryptor decryptor := algorithms.decryptorFor("AES", key);

            AccountManager accountManager = new AccountManager();
            Connection     connection     = accountManager.init(repository, hostDir, buildDir,
                                                decryptor, errors);

            // create a container for the platformUI controller and configure it
            console.print($"Info: Starting the HostManager...");

            ModuleTemplate hostModule = repository.getResolvedModule("host.xqiz.it");
            HostManager    hostManager;
            if (Container  container :=
                    utils.createContainer(repository, hostModule, hostDir, buildDir, True, [], errors)) {
                hostManager = container.invoke("configure", Tuple:(accountsDir))[0].as(HostManager);
            } else {
                return;
            }

            // create a container for the platformUI controller and configure it
            console.print($"Info: Starting the platform UI controller...");

            DBRealm realm;
            if (accountManager.initialized) {
                realm = new DBRealm(names.PlatformRealm, connection);
            } else {
                String userName    = "admin";
                String accountName = "self";

                import common.model.AccountInfo;
                import common.model.UserInfo;
                using (val tx = connection.createTransaction()) {
                    Configuration initConfig = new Configuration(
                        initUserPass  = [userName=password],
                        initRoleUsers = ["Admin"=[userName]]
                        );

                    realm = new DBRealm(names.PlatformRealm,
                                rootSchema = connection, initConfig = initConfig);

                    assert auth.User   user    := tx.authSchema.users.findByName(userName);
                    assert AccountInfo account := accountManager.createAccount(accountName);
                    assert UserInfo    admin   := accountManager.createUser(user.userId, userName,
                                                    $"{userName}@{hostName}");
                    assert accountManager.updateAccount(account.addOrUpdateUser(admin.id, Admin));
                }
            }

            ModuleTemplate uiModule = repository.getResolvedModule("platformUI.xqiz.it");
            if (Container  container :=
                    utils.createContainer(repository, uiModule, hostDir, buildDir, True, [], errors)) {

                import HttpServer.ProxyCheck;

                HostInfo   binding   = new HostInfo(IPAddress.IPv4Any, httpPort, httpsPort);
                ProxyCheck isTrusted = proxies.empty
                        ? HttpServer.NoTrustedProxies
                        : (ip -> proxies.contains(ip));

                @Inject HttpServer server;
                server.bind(binding, isTrusted);

                container.invoke("configure",
                        Tuple:(server, hostName, keystore, realm, accountManager, hostManager, errors));
            } else {
                return;
            }

            console.print($"Info: Started the XtcPlatform at https://{hostName}");

            // TODO create and configure the IO-manager, secret-manager, etc.
        } catch (Exception e) {
            errors.add($"Error: Failed to start the XtcPlatform: {e}");
        } finally {
            errors.reportAll(msg -> console.print(msg));
        }
    }
}