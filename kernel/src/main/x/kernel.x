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
    package platformDB2 import platformDB2.xqiz.it;

    import ecstasy.mgmt.Container;
    import ecstasy.mgmt.ModuleRepository;

    import ecstasy.reflect.ModuleTemplate;

    import common.ErrorLog;
    import common.HostManager;
    import common.HostManager2;
    import common.utils;

    import json.Doc;
    import json.Parser;

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
        Directory platformDir = homeDir.dirFor("xqiz.it/platform");
        platformDir.ensure();

        Directory usersDir = homeDir.dirFor("xqiz.it/users");
        usersDir.ensure();

        Directory buildDir = platformDir.dirFor("build");
        buildDir.ensure();

        // get the configuration
        Map<String, Doc> config;
        try {
            File configFile = platformDir.fileFor("cfg.json");
            if (!configFile.exists) {
                configFile.contents = #/cfg.json; // create a copy from the embedded resource
            }

            String jsonConfig = configFile.contents.unpackUtf8();
            config = new Parser(jsonConfig.toReader()).parseDoc().as(Map<String, Doc>);
        } catch (Exception e) {
            console.print($"Error: Invalid config file");
            return;
        }

        ErrorLog errors = new ErrorLog();
        try {
            // initialize the account manager
            console.print($"Starting the AccountManager..."); // inside the kernel for now
            AccountManager accountManager = new AccountManager();
            accountManager.initDB(repository, platformDir, buildDir, errors);

            // create a container for the platformUI controller and configure it
            console.print($"Starting the HostManager...");

            File storeFile = platformDir.fileFor("certs.p12");
            import crypto.KeyStore;
            @Inject(opts=new KeyStore.Info(storeFile.contents, password)) KeyStore keystore;

            ModuleTemplate hostModule = repository.getResolvedModule("host.xqiz.it");
            HostManager    hostManager;
            HostManager2   hostManager2;
            if (Container  container :=
                    utils.createContainer(repository, hostModule, buildDir, True, errors)) {
                hostManager = container.invoke("configure", Tuple:(usersDir, keystore))[0].as(HostManager);
                hostManager2 = container.invoke("configure2", Tuple:(usersDir, keystore))[0].as(HostManager2);
            } else {
                return;
            }

            // initialize the second account manager
            // after the HostManager so w can pass a reference
            console.print($"Starting the AccountManager2..."); // inside the kernel for now
            AccountManager2 accountManager2 = new AccountManager2();
            accountManager2.init(repository, platformDir, buildDir, hostManager2, errors);


            // create a container for the platformUI controller and configure it
            console.print($"Starting the platform UI controller...");

            ModuleTemplate uiModule = repository.getResolvedModule("platformUI.xqiz.it");
            if (Container  container := utils.createContainer(repository, uiModule, buildDir, True, errors)) {
                String hostName  = config.getOrDefault("hostName",    "xtc-platform.xqiz.it").as(String);
                String bindAddr  = config.getOrDefault("bindAddress", "xtc-platform.xqiz.it").as(String);
                UInt16 httpPort  = config.getOrDefault("httpPort",     8080).as(IntLiteral).toUInt16();
                UInt16 httpsPort = config.getOrDefault("httpsPort",    8090).as(IntLiteral).toUInt16();
                UInt16 portLow   = config.getOrDefault("userPortLow",  8100).as(IntLiteral).toUInt16();
                UInt16 portHigh  = config.getOrDefault("userPortHIgh", 8199).as(IntLiteral).toUInt16();

                container.invoke("configure",
                    Tuple:(accountManager, accountManager2, hostManager, hostName, bindAddr,
                           httpPort, httpsPort, keystore, portLow..portHigh));

                console.print($"Started the XtcPlatform at http://{hostName}:{httpPort}");
            } else {
                return;
            }

            // TODO create and configure the account-, IO-, keyStore-manager, etc.
        } catch (Exception e) {
            errors.add($"Error: Failed to start the XtcPlatform: {e}");
        } finally {
            errors.reportAll(msg -> console.print(msg));
        }
    }
}