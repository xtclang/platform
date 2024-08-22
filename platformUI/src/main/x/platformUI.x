/**
 * The web module for basic hosting functionality.
 */
@WebApp
module platformUI.xqiz.it {
    package common    import common.xqiz.it;
    package challenge import challenge.xqiz.it;

    package auth   import webauth.xtclang.org;
    package crypto import crypto.xtclang.org;
    package json   import json.xtclang.org;
    package net    import net.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    import common.AccountManager;
    import common.ErrorLog;
    import common.HostManager;
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

    @Inject Console console;

    /**
     * Configure the controller.
     */
    void configure(HttpServer server, String hostName, String dName, String provider,
                   Directory homeDir, KeyStore keystore, CryptoPassword pwd, Realm realm,
                   AccountManager accountManager, HostManager hostManager,
                   ErrorLog errors) {
        // the 'hostName' is a full URI of the platform server, e.g. "xtc-platform.localhost.xqiz.it";
        // we need to extract the base domain ("localhost.xqiz.it")
        String baseDomain;
        if (Int dot := hostName.indexOf('.')) {
            baseDomain = hostName.substring(dot + 1);
        } else {
            throw new IllegalState($"Invalid host address: {hostName.quoted()}");
        }

        ControllerConfig.init(accountManager, hostManager, server, baseDomain, keystore, realm);

        HostInfo route = new HostInfo(hostName);

        import challenge.AcmeChallenge;
        HttpHandler.CatalogExtras extras =
            [
            AcmeChallenge = () -> new AcmeChallenge(homeDir.dirFor(".challenge").ensure())
            ];

        server.addRoute(route, new HttpHandler(route, this, extras), keystore,
                        names.PlatformTlsKey, names.CookieEncryptionKey);

        ensureCertificate^(keystore, pwd, hostName, dName, provider, homeDir);

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
                    if (appInfo.autoStart) {
                        if (hostManager.createWebHost(accountName, appInfo,
                                accountManager.decrypt(appInfo.password), errors)) {
                            reportInitialized(appInfo, "Web");
                            continue;
                        }
                        accountManager.addOrUpdateApp(accountName, appInfo.with(autoStart=False));
                        reportFailedInitialization(appInfo, "Web", errors);
                    }
                    // set up the stub in either case
                    hostManager.addStubRoute(accountName, appInfo);
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
                           String provider, Directory homeDir) {
        // schedule the check once a week
        @Inject Clock clock;
        clock.schedule(Duration.ofDays(14), () ->
                ensureCertificate(keystore, pwd, hostName, dName, provider, homeDir));

        Boolean exists = False;
        CheckValid:
        if (Certificate cert := keystore.getCertificate(names.PlatformTlsKey)) {
            String cname = cert.issuer.splitMap().getOrDefault("CN", "");

            exists = True;
            if (provider != "self" && cname == hostName) {
                // the current certificate is self-issued; replace with a real one
                break CheckValid;
            }

            Int daysLeft = (cert.lifetime.upperBound - clock.now.date).days;
            if (daysLeft > 14) {
                console.print($|Info: The certificate for "{cname}" is valid for {daysLeft} more days
                             );
                return;
            }
        }

        File storeFile = homeDir.fileFor(names.PlatformKeyStore);
        assert storeFile.exists;

        // create or renew the certificate
        @Inject(opts=provider) CertificateManager manager;

        manager.createCertificate(storeFile, pwd, names.PlatformTlsKey, dName);

        console.print($|Info: {exists ? "Renewed" : "Created"} a certificate for "{hostName}"
                     );
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
    }
}