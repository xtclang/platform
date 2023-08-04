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
    import common.AccountManager2;
    import common.HostManager;

    import crypto.KeyStore;

    import json.Schema;

    import web.StaticContent;
    import web.WebApp;
    import web.WebService;

    import web.security.Authenticator;
    import web.security.DigestAuthenticator;
    import web.security.FixedRealm;

    /**
     * Configure the controller.
     */
    void configure(AccountManager accountManager, AccountManager2 accountManager2, HostManager hostManager,
                   String hostName, String bindAddr, UInt16 httpPort, UInt16 httpsPort, KeyStore keystore,
                   Range<UInt16> userPorts) {
        ControllerConfig.init(accountManager, accountManager2, hostManager,
            xenia.createServer(this, hostName, bindAddr, httpPort, httpsPort, keystore),
            hostName, bindAddr, userPorts);

        this.registry_.jsonSchema = new Schema(
                enableReflection = True,
                enableMetadata   = True,
                enablePointers   = False,
                randomAccess     = True);
    }


    /**
     * The static content.
     */
    @WebService("/")
    service Content()
            incorporates StaticContent(path, /gui) {
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

    @WebService("/old")
    service OldUIContent()
            incorporates StaticContent(path, /old_gui) {
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
        AccountManager2 accountManager2;

        @Unassigned
        HostManager hostManager;

        @Unassigned
        function void() shutdownServer;

        /**
         * TEMPORARY: the host name, bind address and allowed port range to create user web servers.
         */
        @Unassigned
        String hostName;

        @Unassigned
        String bindAddr;

        @Unassigned
        Range<UInt16> userPorts;

        void init(AccountManager accountManager, AccountManager2 accountManager2, HostManager hostManager,
                 function void() shutdownServer,
                 String hostName, String bindAddr, Range<UInt16> userPorts) {
            this.accountManager  = accountManager;
            this.accountManager2 = accountManager2;
            this.hostManager     = hostManager;
            this.shutdownServer  = shutdownServer;
            this.hostName        = hostName;
            this.bindAddr        = bindAddr;
            this.userPorts       = userPorts;
        }
    }

    /**
     * WebApp.AuthenticatorFactory API.
     * TODO: replace with webauth.DBRealm
     */
    Authenticator createAuthenticator() {
        return new DigestAuthenticator(new FixedRealm("Platform",
            ["acme"="password", "cvs"="password"]));
    }
}