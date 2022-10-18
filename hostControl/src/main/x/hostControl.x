/**
 * The web module for basic hosting functionality.
 */
@web.WebApp
module hostControl.xqiz.it
    {
    package common import common.xqiz.it;
    package json   import json.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    import common.HostManager;

    /**
     * Configure the host controller.
     */
    void configure(HostManager mgr, String address)
        {
        ControllerConfig.init(mgr, xenia.createServer(address, this));
        }

    /**
     * The web site static content.
     */
    @web.StaticContent("/", Directory:/gui)
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