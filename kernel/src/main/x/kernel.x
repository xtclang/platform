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
    package jsondb import jsondb.xtclang.org;
    package oodb   import oodb.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    package common     import common.xqiz.it;
    package platformDB import platformDB.xqiz.it;

    import ecstasy.mgmt.Container;
    import ecstasy.mgmt.ModuleRepository;

    import ecstasy.reflect.ModuleTemplate;

    import common.ErrorLog;
    import common.HostManager;

    import common.utils;

    void run(String[] args=[]) {
        @Inject Console          console;
        @Inject Directory        homeDir;
        @Inject ModuleRepository repository;

        String password;
        if (args.size == 0) {
            console.print("Enter password:");
            password = console.readLine(suppressEcho=True);
        } else {
            password = args[0];
        }

        Directory platformDir = homeDir.dirFor("xqiz.it/platform");
        platformDir.ensure();

        Directory buildDir = platformDir.dirFor("build");
        buildDir.ensure();

        ErrorLog errors = new ErrorLog();

        try {
            // initialize the account manager
            console.print($"Starting the AccountManager..."); // inside the kernel for now
            AccountManager accountManager = new AccountManager();
            accountManager.initDB(repository, platformDir, buildDir, errors);

            // create a container for the platformUI controller and configure it
            console.print($"Starting the HostManager...");

            ModuleTemplate hostModule = repository.getResolvedModule("host.xqiz.it");
            HostManager    hostManager;
            if (Container  container :=
                    utils.createContainer(repository, hostModule, buildDir, True, errors)) {
                hostManager = container.invoke("configure", Tuple:())[0].as(HostManager);
            } else {
                return;
            }

            // create a container for the platformUI controller and configure it
            console.print($"Starting the platform UI controller...");

            ModuleTemplate uiModule = repository.getResolvedModule("platformUI.xqiz.it");
            if (Container  container := utils.createContainer(repository, uiModule, buildDir, True, errors)) {
                String hostName  = "admin.xqiz.it";
                File   storeFile = platformDir.fileFor("certs.p12");
                UInt16 httpPort  = 8080;
                UInt16 httpsPort = 8090;

                import crypto.KeyStore;
                @Inject(opts=new KeyStore.Info(storeFile.contents, password)) KeyStore keystore;

                container.invoke("configure",
                    Tuple:(accountManager, hostManager, hostName, keystore, httpPort, httpsPort));

                console.print($"Started the XtcPlatform at http://{hostName}:{httpPort}");
            } else {
                return;
            }

            // TODO create and configure the account-, IO-, keyStore-manager, etc.
        } finally {
            errors.reportAll(msg -> console.print(msg));
        }
    }
}