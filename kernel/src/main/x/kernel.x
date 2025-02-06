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
    package convert import convert.xtclang.org;
    package crypto  import crypto.xtclang.org;
    package json    import json.xtclang.org;
    package jsondb  import jsondb.xtclang.org;
    package oodb    import oodb.xtclang.org;
    package net     import net.xtclang.org;
    package sec     import sec.xtclang.org;
    package web     import web.xtclang.org;
    package webauth import webauth.xtclang.org;
    package xenia   import xenia.xtclang.org;

    package common      import common.xqiz.it;
    package platformDB  import platformDB.xqiz.it;

    import ecstasy.mgmt.Container;
    import ecstasy.mgmt.ModuleRepository;

    import ecstasy.reflect.ModuleTemplate;

    import common.ErrorLog;
    import common.HostManager;
    import common.KernelHost;
    import common.ProxyManager;

    import common.names;
    import common.utils;

    import platformDB.Connection;

    import crypto.CertificateManager;
    import crypto.CryptoPassword;
    import crypto.Decryptor;
    import crypto.KeyStore;
    import crypto.NamedPassword;

    import json.Doc;
    import json.Parser;

    import net.IPAddress;
    import net.Uri;

    import web.http.HostInfo;

    import xenia.HttpServer;

    @Inject Console console;

    void run(String[] args=[]) {
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
            if (configFile.exists) {
                if (configFile.modified <= configInit.modified) {
                    console.print($|Warning: Your local config file is out of date; \
                                   |please make sure it confirms to the current structure
                                 );
                }
                jsonConfig = configFile.contents.unpackUtf8();
            } else {
                // create a copy from the embedded resource
                immutable Byte[] configData = configInit.contents;
                jsonConfig = configData.unpackUtf8();
                configFile.contents = configData;
            }

            config = new Parser(jsonConfig.toReader()).parseDoc().as(Map<String, Doc>);
        } catch (Exception e) {
            console.print($"Error: Invalid config file");
            return;
        }

        ErrorLog errors = new ErrorLog();
        try {
            String   dName     = config.getOrDefault("dName", "").as(String);
            String   provider  = config.getOrDefault("cert-provider", "self").as(String);
            UInt16   httpPort  = config.getOrDefault("httpPort",  8080).as(IntLiteral).toUInt16();
            UInt16   httpsPort = config.getOrDefault("httpsPort", 8090).as(IntLiteral).toUInt16();
            String[] proxies   = config.getOrDefault("proxies", []).as(Doc[])
                                       .map(addr -> addr.as(String)).toArray();

            assert String hostName := dName.splitMap().get("CN"), hostName.count('.') >= 2
                    as "Invalid \"dName\" configuration value";

            File storeFile = platformDir.fileFor(names.KeyStoreName);
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
                manager.createSymmetricKey(storeFile, password, names.CookieEncryptionKey);
                manager.createSymmetricKey(storeFile, password, names.PasswordEncryptionKey);

                // Note: the certificate creation will be done by platformUI.ensureCertificate()
                }

            @Inject(opts=new KeyStore.Info(storeFile.contents, password)) KeyStore keystore;

            Decryptor decryptor = utils.createDecryptor(keystore);

            // initialize the account manager; it's inside the kernel for now, but we need to
            // consider creating a separate container for it
            console.print("Info: Starting the AccountManager...");

            AccountManager accountManager = new AccountManager();
            Connection     connection     = accountManager.init(repository, hostDir, buildDir,
                                                                decryptor, errors);
            import webauth.DBRealm;

            DBRealm realm;
            if (accountManager.initialized) {
                realm = new DBRealm(names.PlatformRealm, connection);
            } else {
                String userName    = "admin";
                String accountName = "self";

                import common.model.AccountInfo;
                import common.model.UserInfo;
                import sec.Principal;
                import web.security.DigestCredential;
                import webauth.Configuration;

                using (val tx = connection.createTransaction()) {
                    String        credScheme = DigestCredential.Scheme;
                    Configuration initConfig = new Configuration(
                        initUserPass = [userName=password],
                        credScheme   = credScheme,
                        );

                    realm = new DBRealm(names.PlatformRealm, rootSchema=connection, initConfig=initConfig);

                    assert Principal   user    := realm.findPrincipal(credScheme, userName.quoted());
                    assert AccountInfo account := accountManager.createAccount(accountName);
                    assert UserInfo    admin   := accountManager.createUser(user.principalId, userName,
                                                    $"{userName}@{hostName}");
                    assert accountManager.updateAccount(account.addOrUpdateUser(admin.id));
                }
            }

            @Inject(resourceName="server") HttpServer httpServer;

            KernelHost pseudoHost = new KernelHost(hostDir, buildDir);

            // load the proxy manager (assume it may be missing)
            ProxyManager proxyManager;
            IPAddress[]  proxyIPs = [];
            if (proxies.empty) {
                proxyManager = NoProxies;
            } else {
                if (ModuleTemplate proxyModule := repository.getModule("proxy_manager.xqiz.it")) {
                    proxyModule = proxyModule.parent.resolve(repository).mainModule;

                    (Uri[] receivers, proxyIPs) = parseProxies(proxies);
                    if (Container container :=
                            utils.createContainer(repository, proxyModule, pseudoHost, errors)) {
                        proxyManager = container.invoke("configure", Tuple:(receivers))[0].as(ProxyManager);
                    } else {
                        return;
                    }
                } else {
                    proxyManager = NoProxies;
                    console.print(\|Warning: Failed to load the ProxyManager; new deployment \
                                   |configurations *will not be* propagated to proxy servers
                                 );
                }
            }

            // create a container for the host manager and configure it
            console.print("Info: Starting the HostManager...");

            ModuleTemplate hostModule = repository.getResolvedModule("host.xqiz.it");
            HostManager    hostManager;
            if (Container  container :=
                    utils.createContainer(repository, hostModule, pseudoHost, errors)) {
                hostManager = container.invoke("configure",
                                Tuple:(httpServer, accountsDir, proxyManager))[0].as(HostManager);
            } else {
                return;
            }

            // create a container for the platformUI controller and configure it
            console.print("Info: Starting the platform UI controller...");

            ModuleTemplate uiModule = repository.getResolvedModule("platformUI.xqiz.it");
            if (Container  container :=
                    utils.createContainer(repository, uiModule, pseudoHost, errors)) {
                import HttpServer.ProxyCheck;

                HostInfo   binding   = new HostInfo(IPAddress.IPv4Any, httpPort, httpsPort);
                ProxyCheck isTrusted = proxyIPs.empty
                        ? HttpServer.NoTrustedProxies
                        : (ip -> proxyIPs.contains(ip));

                httpServer.bind(binding, isTrusted);

                CryptoPassword pwd = new NamedPassword("", password);

                container.invoke("configure",
                        Tuple:(httpServer, hostName, dName, provider, platformDir,
                               &pwd.maskAs(CryptoPassword), realm,
                               &accountManager.maskAs(common.AccountManager), hostManager,
                               proxyManager, errors));
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

    private (Uri[] uris, IPAddress[] addrs) parseProxies(String[] proxies) {
        @Inject("secureNetwork") net.Network network;

        Int         count = proxies.size;
        Uri[]       uris  = new Array<Uri>(count);
        IPAddress[] addrs = new Array<IPAddress>(count);

        for (String proxy : proxies) {
            assert Int portOffset := proxy.lastIndexOf(':') as
                    $"Proxy port must be specified: {proxy.quoted()}";
            String addr = proxy[0 ..< portOffset];
            UInt16 port = new UInt16(proxy.substring(portOffset + 1));

            if (Byte[] bytes := IPAddress.parse(addr)) {
                IPAddress ipAddr = new IPAddress(bytes);
                addrs += ipAddr;

                if (String host := network.nameService.reverseLookup(ipAddr)) {
                    uris += new Uri(scheme="https", host=host, port=port);
                } else {
                    uris += new Uri(scheme="https", host=addr, port=port);
                    console.print($"Failed to lookup the proxy name: {proxy.quoted()}");
                }
            } else {
                assert IPAddress[] ips := network.nameService.resolve(addr), !ips.empty as
                    $"Unresolvable proxy name: {proxy.quoted()}";
                addrs += ips; // if more than one (quite rare), add them all
                uris += new Uri(scheme="https", host=addr, port=port);
            }
        }
        return uris.freeze(inPlace=True), addrs.freeze(inPlace=True);
    }
}