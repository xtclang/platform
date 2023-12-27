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
    import common.WebHost;

    import common.names;

    import crypto.KeyStore;

    import json.Schema;

    import web.HttpsRequired;
    import web.StaticContent;
    import web.WebApp;
    import web.WebService;

    import web.security.FixedRealm;
    import web.security.Realm;

    import xenia.HttpHandler;
    import xenia.HttpServer;

    /**
     * Configure the controller.
     */
    void configure(AccountManager accountManager, HostManager hostManager,
                   String hostAddr, UInt16 httpPort, UInt16 httpsPort, KeyStore keystore,
                   WebHost[] webHosts) {
        // the 'hostAddr' is a full URI of the platform server, e.g. "xtc-platform.localhost.xqiz.it";
        // we need to extract the base domain ("localhost.xqiz.it")
        String baseDomain;
        if (Int dot := hostAddr.indexOf('.')) {
            baseDomain = hostAddr.substring(dot + 1);
        } else {
            throw new IllegalState($"Invalid host address: {hostAddr.quoted()}");
        }

        @Inject HttpServer server;
        try {
            server.configure(hostAddr, httpPort, httpsPort);

            server.addRoute(hostAddr, new HttpHandler(server, this), keystore,
                    names.PlatformTlsKey, names.CookieEncryptionKey);

            for (WebHost webHost : webHosts) {
                webHost.httpServer = server;
                @Inject Console console;
                console.print($"TODO server.addRoute({webHost.info.hostName}");
            }

            server.start();

            ControllerConfig.init(accountManager, hostManager, server, baseDomain);
            }
        catch (Exception e) {
            server.close(e);
            throw e;
        }

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
        HttpServer httpServer;

        @Unassigned
        String baseDomain;

        void init(AccountManager accountManager, HostManager hostManager,
                  HttpServer httpServer, String baseDomain) {
            this.accountManager = accountManager;
            this.hostManager    = hostManager;
            this.httpServer     = httpServer;
            this.baseDomain     = baseDomain;
        }

      /**
       * TODO: replace with webauth.DBRealm
       */
      Realm realm = new FixedRealm("Platform", ["admin@acme.com"="password", "admin@cvs.com"="password"]);
    }
}