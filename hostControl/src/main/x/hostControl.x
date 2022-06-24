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
    void configure(HostManager mgr, HttpServer httpServer)
        {
        WebServer webServer = new WebServer(httpServer);
        webServer.addWebService(new Controller(mgr, webServer)); // TODO: Controller factory?
        webServer.addWebService(new Content());
        webServer.start();

        @Inject Console console;
        console.println("Started the XtcPlatform at http://admin.xqiz.it:8080");
        }

    /**
     * The web site static content.
     */
    @web.StaticContent(/gui, ALL_TYPE)
    service Content
        {
        }
    }