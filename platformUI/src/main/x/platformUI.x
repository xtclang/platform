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

    import common.AccountManager;
    import common.HostManager;

    /**
     * Configure the controller.
     */
    void configure(AccountManager accountManager, HostManager hostManager,
                   String hostName, File keyStore, String password, UInt16 httpPort, UInt16 httpsPort)
        {
        ControllerConfig.init(accountManager, hostManager,
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
        AccountManager accountManager;

        @Unassigned
        HostManager hostManager;

        @Unassigned
        function void() shutdownServer;

        void init(AccountManager accountManager, HostManager hostManager, function void() shutdownServer)
            {
            this.accountManager = accountManager;
            this.hostManager    = hostManager;
            this.shutdownServer = shutdownServer;
            }
        }
    }