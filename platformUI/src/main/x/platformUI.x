/**
 * The web module for basic hosting functionality.
 */
@WebApp
module platformUI.xqiz.it {
    package auth   import webauth.xtclang.org;
    package common import common.xqiz.it;
    package crypto import crypto.xtclang.org;
    package json   import json.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    import common.AccountManager;
    import common.ErrorLog;
    import common.HostManager;
    import common.WebHost;

    import common.names;

    import common.model.AccountInfo;
    import common.model.WebAppInfo;

    import crypto.KeyStore;

    import json.Schema;

    import web.HttpsRequired;
    import web.StaticContent;
    import web.WebApp;
    import web.WebService;

    import web.http.HostInfo;

    import web.security.Authenticator;
    import web.security.TokenAuthenticator;
    import web.security.Realm;

    import xenia.HttpHandler;
    import xenia.HttpServer;

    /**
     * Configure the controller.
     */
    void configure(HttpServer server, String hostAddr, KeyStore keystore, Realm realm,
                   AccountManager accountManager, HostManager hostManager, ErrorLog errors) {
        // the 'hostAddr' is a full URI of the platform server, e.g. "xtc-platform.localhost.xqiz.it";
        // we need to extract the base domain ("localhost.xqiz.it")
        String baseDomain;
        if (Int dot := hostAddr.indexOf('.')) {
            baseDomain = hostAddr.substring(dot + 1);
        } else {
            throw new IllegalState($"Invalid host address: {hostAddr.quoted()}");
        }

        ControllerConfig.init(accountManager, hostManager, server, baseDomain, keystore, realm);

        HostInfo route = new HostInfo(hostAddr);
        server.addRoute(route, new HttpHandler(route, this), keystore,
                names.PlatformTlsKey, names.CookieEncryptionKey);

        // create WebHosts for all active web applications
        @Inject Console console;

        for (AccountInfo accountInfo : accountManager.getAccounts()) {
            for (WebAppInfo webAppInfo : accountInfo.webApps.values) {
                if (webAppInfo.active) {
                    if (WebHost webHost :=
                        hostManager.createWebHost(server, accountInfo.name, webAppInfo,
                                accountManager.decrypt(webAppInfo.password), errors)) {
                        console.print($|Info: Initialized deployment: "{webAppInfo.hostName}" \
                                       |of "{webAppInfo.moduleName}"
                                     );
                    }
                    // there must be an error logged
                } else {
                    ControllerConfig.addStubRoute(webAppInfo.hostName);
                }
            }
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
            incorporates StaticContent(path, Directory:/build) {
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
     * WebApp.AuthenticatorFactory API.
     */
    Authenticator createAuthenticator() {
        return new TokenAuthenticator(ControllerConfig.realm);
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

        @Unassigned
        KeyStore keystore;

        @Unassigned
        Realm realm;

        void init(AccountManager accountManager, HostManager hostManager,
                  HttpServer httpServer, String baseDomain, KeyStore keystore, Realm realm) {
            this.accountManager = accountManager;
            this.hostManager    = hostManager;
            this.httpServer     = httpServer;
            this.baseDomain     = baseDomain;
            this.keystore       = keystore;
            this.realm          = realm;
        }

        /**
         * Add a stub route for the specified deployment.
         */
        void addStubRoute(String hostName) {
            StubHandler handler = new StubHandler(/build/not-deployed.html, ["%deployment%"=hostName]);

            httpServer.addRoute(hostName, handler, keystore,
                    names.PlatformTlsKey, names.CookieEncryptionKey);
        }
    }
}