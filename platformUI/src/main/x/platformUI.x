/**
 * The web module for basic hosting functionality.
 */
@WebApp
module platformUI.xqiz.it {
    package common import common.xqiz.it;
    package crypto import crypto.xtclang.org;
    package json   import json.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    import common.AccountManager;
    import common.HostManager;

    import crypto.KeyStore;

    import json.Schema;

    import web.HttpsRequired;
    import web.StaticContent;
    import web.WebApp;
    import web.WebService;

    import web.security.FixedRealm;
    import web.security.Realm;

    /**
     * Configure the controller.
     */
    void configure(AccountManager accountManager, HostManager hostManager,
                   String bindAddr, UInt16 httpPort, UInt16 httpsPort, KeyStore keystore,
                   Range<UInt16> userPorts) {
        ControllerConfig.init(accountManager, hostManager,
            xenia.createServer(this, bindAddr, httpPort, httpsPort, keystore),
            bindAddr, userPorts);

        this.registry_.jsonSchema = new Schema(
                enableReflection = True,
                enableMetadata   = True,
                enablePointers   = False,
                randomAccess     = True);
    }

    /**
     * The static content (Quasar: Single Page Application).
     */
    @WebService("/")
    @HttpsRequired
    service Content()
            incorporates StaticContent(path, Directory:/spa) {
        import web.Get;
        import web.ResponseOut;

        @Get("{path}")
        @Override
        conditional ResponseOut getResource(String path) {
            if (ResponseOut response := super(path)) {
                return True, response;
            }
            return super(defaultPage);
        }
    }

    /**
     * The singleton service holding configuration info.
     */
    static service ControllerConfig {

        @Unassigned
        AccountManager accountManager;

        @Unassigned
        HostManager hostManager;

        @Unassigned
        function void() shutdownServer;

        @Unassigned
        String bindAddr;

        @Unassigned
        Range<UInt16> userPorts;

        void init(AccountManager accountManager, HostManager hostManager,
                 function void() shutdownServer,
                 String bindAddr, Range<UInt16> userPorts) {
            this.accountManager = accountManager;
            this.hostManager    = hostManager;
            this.shutdownServer = shutdownServer;
            this.bindAddr       = bindAddr;
            this.userPorts      = userPorts;
        }

      /**
       * TODO: replace with webauth.DBRealm
       */
      Realm realm = new FixedRealm("Platform", ["admin@acme.com"="password", "admin@cvs.com"="password"]);
    }
}