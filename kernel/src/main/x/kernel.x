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
    import common.WebHost;

    import common.names;
    import common.utils;

    import common.model.AccountInfo;
    import common.model.WebAppInfo;

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
            console.print($"Info: Starting the AccountManager..."); // inside the kernel for now
            AccountManager accountManager = new AccountManager();
            accountManager.init(repository, hostDir, buildDir, errors);

            // create a container for the platformUI controller and configure it
            console.print($"Info: Starting the HostManager...");

            File storeFile = platformDir.fileFor(names.PlatformKeyStore);
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

            String hostAddr  = config.getOrDefault("hostAddr",  names.PlatformUri).as(String);
            UInt16 httpPort  = config.getOrDefault("httpPort",  8080).as(IntLiteral).toUInt16();
            UInt16 httpsPort = config.getOrDefault("httpsPort", 8090).as(IntLiteral).toUInt16();

            @Inject HttpServer server;
            server.configure(hostAddr, httpPort, httpsPort);

            ModuleTemplate uiModule = repository.getResolvedModule("platformUI.xqiz.it");
            if (Container  container :=
                    utils.createContainer(repository, uiModule, hostDir, buildDir, True, errors)) {

                container.invoke("configure",
                        Tuple:(server, hostAddr, keystore, accountManager, hostManager));
            } else {
                return;
            }

            // create WebHosts for all active web applications
            WebHost[] webHosts = new WebHost[];
            for (AccountInfo accountInfo : accountManager.getAccounts()) {
                for (WebAppInfo webAppInfo : accountInfo.webApps.values) {
                    if (webAppInfo.active, WebHost webHost :=
                            hostManager.createWebHost(server, accountInfo.name, webAppInfo, errors)) {
                        webHosts += webHost;
                        console.print($|Info: Initialized deployment: "{webAppInfo.hostName}" \
                                       |of "{webAppInfo.moduleName}"
                                     );
                    }
                }
            }

            server.start();
            console.print($"Info: Started the XtcPlatform at https://{hostAddr}");

            // TODO create and configure the IO-manager, secret-manager, etc.
        } catch (Exception e) {
            errors.add($"Error: Failed to start the XtcPlatform: {e}");
        } finally {
            errors.reportAll(msg -> console.print(msg));
        }
    }
}