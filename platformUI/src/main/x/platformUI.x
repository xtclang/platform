/**
 * The web module for basic hosting functionality.
 */
@WebApp
module platformUI.xqiz.it {
    package common       import common.xqiz.it;
    package challenge    import challenge.xqiz.it;
    package platformAuth import auth.xqiz.it;

    package conv    import convert.xtclang.org;
    package crypto  import crypto.xtclang.org;
    package json    import json.xtclang.org;
    package net     import net.xtclang.org;
    package sec     import sec.xtclang.org;
    package web     import web.xtclang.org;
    package webauth import webauth.xtclang.org;
    package xenia   import xenia.xtclang.org;

    import common.AccountManager;
    import common.ErrorLog;
    import common.HostManager;
    import common.ProxyManager;
    import common.WebHost;

    import common.names;

    import common.model.AccountInfo;
    import common.model.AppInfo;
    import common.model.DbAppInfo;
    import common.model.WebAppInfo;

    import crypto.Certificate;
    import crypto.CertificateManager;
    import crypto.CryptoPassword;
    import crypto.KeyStore;

    import json.Schema;

    import sec.Realm;

    import web.HttpsRequired;
    import web.StaticContent;
    import web.WebApp;
    import web.WebService;

    import web.http.HostInfo;

    import webauth.DBRealm;

    import xenia.HttpHandler;
    import xenia.HttpServer;

    @Inject Clock   clock;
    @Inject Console console;

    /**
     * Configure the controller.
     */
    void configure(HttpServer server, String hostName, String dName, String provider,
                   Directory homeDir, CryptoPassword pwd, DBRealm realm,
                   AccountManager accountManager, HostManager hostManager, ProxyManager proxyManager,
                   ErrorLog errors) {
        // the 'hostName' is a full URI of the platform server, e.g. "xtc-platform.localhost.xqiz.it";
        // we need to extract the base domain ("localhost.xqiz.it")
        String baseDomain;
        if (Int dot := hostName.indexOf('.')) {
            baseDomain = hostName.substring(dot + 1);
        } else {
            throw new IllegalState($"Invalid host address: {hostName.quoted()}");
        }

        File storeFile = homeDir.fileFor(names.KeyStoreName);
        @Inject(opts=new KeyStore.Info(storeFile.contents, pwd)) KeyStore keystore;

        HostInfo route = new HostInfo(hostName);

        import challenge.AcmeChallenge;
        import platformAuth.UserEndpoint;
        import web.security.NeverAuthenticator;
        HttpHandler.CatalogExtras extras =
            [
            UserEndpoint  = () -> new UserEndpoint(this, realm, new NeverAuthenticator(this)),
            AcmeChallenge = () -> new AcmeChallenge(homeDir.dirFor(".challenge").ensure()),
            ];

        if (checkCertificate(keystore, hostName, provider)) {
            // they could have configured new proxies; need to update them just in case
            proxyManager.updateProxyConfig^(keystore, pwd, names.PlatformTlsKey, hostName, console.&print);

            // schedule the next check in a week
            clock.schedule(Duration.ofDays(7), () ->
                    ensureCertificate(keystore, pwd, hostName, dName, provider, homeDir, proxyManager));
        } else {
            // before we proceed we need to create a certificate; for that to work (unless the
            // provider is self-signing), we need to activate the challenge app
            server.addRoute(route, new HttpHandler(route, hostManager.challengeApp, extras));
            @Future Tuple result = createCertificate^(
                    keystore, pwd, hostName, dName, provider, homeDir, proxyManager);
            &result.whenComplete((r, e) -> {
                if (e == Null) {
                    server.removeRoute(route);

                    // repeat from the top (reloading the keystore); it should go through now...
                    configure(server, hostName, dName, provider, homeDir, pwd, realm,
                       accountManager, hostManager, proxyManager, errors);
                }});
            return result;
        }

        ControllerConfig.init(accountManager, hostManager, server, baseDomain, keystore, realm);

        server.addRoute(route, new HttpHandler(route, this, extras), keystore,
                        names.PlatformTlsKey, names.CookieEncryptionKey);

        // create AppHosts for all `autoStart` applications
        for (AccountInfo accountInfo : accountManager.getAccounts()) {
            String accountName = accountInfo.name;

            // create DbHosts for `autoStart` db applications first
            for (AppInfo appInfo : accountInfo.apps.values) {
                if (appInfo.autoStart && appInfo.is(DbAppInfo)) {
                    if (hostManager.createDbHost(accountName, appInfo, errors)) {
                        reportInitialized(appInfo, "DB");
                    } else {
                        accountManager.addOrUpdateApp(accountName, appInfo.with(autoStart=False));
                        reportFailedInitialization(appInfo, "DB", errors);
                    }
                }
            }

            // create WebHosts for all `autoStart` web applications
            for (AppInfo appInfo : accountInfo.apps.values) {
                if (appInfo.is(WebAppInfo)) {
                    CryptoPassword storePwd = accountManager.decrypt(appInfo.password);
                    if (appInfo.autoStart) {
                        if (hostManager.createWebHost(accountName, appInfo, storePwd, errors)) {
                            reportInitialized(appInfo, "Web");
                            continue;
                        }
                        accountManager.addOrUpdateApp(accountName, appInfo.with(autoStart=False));
                        reportFailedInitialization(appInfo, "Web", errors);
                    }
                    // set up the stub in either case
                    hostManager.addStubRoute(accountName, appInfo, storePwd);
                }
            }
        }

        this.registry_.jsonSchema = new Schema(
                enableReflection = True,
                enableMetadata   = True,
                enablePointers   = False,
                randomAccess     = True);

        void reportInitialized(AppInfo appInfo, String type) {
            console.print($|Info: Initialized {type} deployment: "{appInfo.deployment}" \
                           |of "{appInfo.moduleName}"
                         );
        }

        void reportFailedInitialization(AppInfo appInfo, String type, ErrorLog errors) {
            console.print($|Warning: Failed to initialize {type} deployment: "{appInfo.deployment}" \
                           |of "{appInfo.moduleName}"
                         );
            errors.reportAll(msg -> console.print(msg));
        }
    }

    /**
     * Make sure the platform certificate is up-to-date.
     */
    void ensureCertificate(KeyStore keystore, CryptoPassword pwd, String hostName, String dName,
                           String provider, Directory homeDir, ProxyManager proxyManager) {
        // re-schedule the check in a week
        clock.schedule(Duration.ofDays(7), () ->
                ensureCertificate(keystore, pwd, hostName, dName, provider, homeDir, proxyManager));

        if (!checkCertificate(keystore, hostName, provider)) {
            createCertificate(keystore, pwd, hostName, dName, provider, homeDir, proxyManager);
        }
    }

    /**
     * Check if the platform certificate exists and valid.
     *
     * @return `True` iff the certificate is valid
     * @return `True` iff the certificate exists
     */
    (Boolean valid, Boolean exists) checkCertificate(KeyStore keystore, String hostName,
                                                     String provider) {
        if (Certificate cert := keystore.getCertificate(names.PlatformTlsKey)) {

            String issuerCN = cert.issuer.splitMap().getOrDefault("CN", "");
            if (issuerCN == hostName && provider != "self") {
                // the current certificate is self-issued; replace using the specified provider
                return False, True;
            }

            String subjectCN = cert.subject.splitMap().getOrDefault("CN", "");
            if (subjectCN != hostName) {
                // the current certificate was issued for a different name; replace
                return False, True;
            }

            Int daysLeft = (cert.lifetime.upperBound - clock.now.date).days;
            if (daysLeft > 14) {
                console.print($|Info: The certificate for "{hostName}" is valid for {daysLeft} more days
                             );
                return True, True;
            }
        }
        return False, False;
    }

    /**
     * Create the platform certificate. This assumes that the "challenge" app is active.
     */
    @Concurrent
    void createCertificate(KeyStore keystore, CryptoPassword pwd, String hostName, String dName,
                           String provider, Directory homeDir, ProxyManager proxyManager) {
        File storeFile = homeDir.fileFor(names.KeyStoreName);
        assert storeFile.exists;

        Boolean exists = keystore.getCertificate(names.PlatformTlsKey);

        @Inject(opts=provider) CertificateManager manager;
        manager.createCertificate(storeFile, pwd, names.PlatformTlsKey, dName);

        console.print($|Info: {exists ? "Renewed" : "Created"} a certificate for "{hostName}"
                     );
        proxyManager.updateProxyConfig^(keystore, pwd, names.PlatformTlsKey, hostName, console.&print);
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

        @Get("{/path}")
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
    }
}