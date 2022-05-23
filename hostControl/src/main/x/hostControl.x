/**
 * The web module for basic hosting functionality.
 */
@web.WebModule
module hostControl.xqiz.it
    {
    package common import common.xqiz.it;
    package web    import web.xtclang.org;

    import common.HostManager;

    import web.HttpServer;
    import web.WebServer;

    /**
     * Configure the host controller.
     */
    void configure(HostManager mgr, HttpServer httpController)
        {
        WebServer controllerServer = new WebServer(httpController);
        controllerServer.addWebService(new Controller(mgr)); // TODO: Controller factory?
        controllerServer.start();

        @Inject Console console;
        console.println("Started the XtcPlatform at http://admin.xqiz.it:8080");
        }
    }