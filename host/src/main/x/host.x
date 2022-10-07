/**
 * The module for core hosting functionality.
 */
module host.xqiz.it
    {
    package oodb   import oodb.xtclang.org;
    package jsondb import jsondb.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    package common import common.xqiz.it;
    package hostDB import hostDB;

    import ecstasy.mgmt.Container;
    import ecstasy.mgmt.ModuleRepository;

    import ecstasy.reflect.ModuleTemplate;

    import common.ErrorLog;

    void run(String[] args=[])
        {
        @Inject Console          console;
        @Inject Directory        curDir;
        @Inject ModuleRepository repository;

        ErrorLog errors = new ErrorLog();

        // create a hostDB container
        console.println($"Creating the manager...");

        HostManager mgr = new HostManager();
        mgr.initDB(repository, errors);

        // create a container for the host controller and configure it
        console.println($"Starting the host controller...");

        ModuleTemplate controlModule = repository.getResolvedModule("hostControl.xqiz.it");
        if (Container container :=
                mgr.createContainer(repository, controlModule, curDir, True, errors))
            {
            String address = "admin.xqiz.it:8080";

            container.invoke("configure", Tuple:(&mgr.maskAs(common.HostManager), address));

            console.println($"Started the XtcPlatform at http://{address}");
            }

        // TODO create and configure the account manager, etc.

        errors.reportAll(msg -> console.println(msg));
        }
    }