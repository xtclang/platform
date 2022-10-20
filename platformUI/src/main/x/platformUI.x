/**
 * The web module for basic hosting functionality.
 */
@web.WebApp
module platformUI.xqiz.it
    {
    package common import common.xqiz.it;
    package json   import json.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    import common.HostManager;

    /**
     * Configure the controller.
     */
    void configure(HostManager mgr, String hostName, File keyStore, String password, UInt16 httpPort, UInt16 httpsPort)
        {
        ControllerConfig.init(mgr,
            xenia.createServer(this, hostName, keyStore, password, httpPort, httpsPort));
        }

    /**
     * The web site static content.
     */
    @web.StaticContent("/", /gui)
    service Content
        {
        }

    /**
     * The singleton service holding configuration info.
     */
    static service ControllerConfig
        {
        @Unassigned
        HostManager mgr;

        @Unassigned
        function void() shutdownServer;

        void init(HostManager mgr, function void() shutdownServer)
            {
            this.mgr            = mgr;
            this.shutdownServer = shutdownServer;
            }
        }
    }