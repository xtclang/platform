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
    package crypto import crypto.xtclang.org;
    package json   import json.xtclang.org;
    package jsondb import jsondb.xtclang.org;
    package oodb   import oodb.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    package common      import common.xqiz.it;
    package platformDB  import platformDB.xqiz.it;

    import ecstasy.mgmt.Container;
    import ecstasy.mgmt.ModuleRepository;

    import ecstasy.reflect.ModuleTemplate;

    import common.ErrorLog;
    import common.HostManager;

    import common.names;
    import common.utils;

    import crypto.CertificateManager;

    import json.Doc;
    import json.Parser;

    import xenia.HttpServer;

    void run(String[] args=[]) {
        @Inject Console          console;
        @Inject Directory        homeDir;
        @Inject ModuleRepository repository;

        // get the password
        String password;
        if (args.size == 0) {
            console.print("Enter password:");
            password = console.readLine(suppressEcho=True);
        } else {
            password = args[0];
        }

        // ensure necessary directories
        Directory platformDir = homeDir.dirFor("xqiz.it/platform").ensure();
        Directory usersDir    = homeDir.dirFor("xqiz.it/users").ensure();
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
                Byte[] configData = configInit.contents;
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
            String hostName  = config.getOrDefault("hostName",  names.PlatformUri).as(String);
            UInt16 httpPort  = config.getOrDefault("httpPort",  8080).as(IntLiteral).toUInt16();
            UInt16 httpsPort = config.getOrDefault("httpsPort", 8090).as(IntLiteral).toUInt16();

            File storeFile = platformDir.fileFor(names.PlatformKeyStore);
            if (!storeFile.exists)
                {
                console.print($|Warning: *** The platform keystore does not exist; creating a new one\
                               | with a self-signed certificate for the platform web server.
                               |Warning: *** The password you have provided will be used to encrypt it.
                             );

                @Inject CertificateManager manager;
                String dName = CertificateManager.distinguishedName(hostName, org="localhost", orgUnit="Platform");

                manager.createCertificate(storeFile, password, names.PlatformTlsKey, dName);
                manager.createSymmetricKey(storeFile, password, names.CookieEncryptionKey);
                }

            // initialize the account manager
            console.print($"Info: Starting the AccountManager..."); // inside the kernel for now
            AccountManager accountManager = new AccountManager();
            accountManager.init(repository, hostDir, buildDir, errors);

            // create a container for the platformUI controller and configure it
            console.print($"Info: Starting the HostManager...");

            import crypto.KeyStore;
            @Inject(opts=new KeyStore.Info(storeFile.contents, password)) KeyStore keystore;

            ModuleTemplate hostModule = repository.getResolvedModule("host.xqiz.it");
            HostManager    hostManager;
            if (Container  container :=
                    utils.createContainer(repository, hostModule, hostDir, buildDir, True, errors)) {
                hostManager = container.invoke("configure", Tuple:(usersDir))[0].as(HostManager);
            } else {
                return;
            }

            // create a container for the platformUI controller and configure it
            console.print($"Info: Starting the platform UI controller...");

            @Inject HttpServer server;
            server.configure(hostName, httpPort, httpsPort);

            ModuleTemplate uiModule = repository.getResolvedModule("platformUI.xqiz.it");
            if (Container  container :=
                    utils.createContainer(repository, uiModule, hostDir, buildDir, True, errors)) {

                container.invoke("configure",
                        Tuple:(server, hostName, keystore, accountManager, hostManager, errors));
            } else {
                return;
            }

            server.start();
            console.print($"Info: Started the XtcPlatform at https://{hostName}");

            // TODO create and configure the IO-manager, secret-manager, etc.
        } catch (Exception e) {
            errors.add($"Error: Failed to start the XtcPlatform: {e}");
        } finally {
            errors.reportAll(msg -> console.print(msg));
        }
    }
}