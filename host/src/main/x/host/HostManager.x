import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import ecstasy.text.Log;

import common.AccountManager;
import common.AppHost;
import common.DbHost;
import common.ProxyManager;
import common.WebHost;

import common.model.DbAppInfo;
import common.model.WebAppInfo;

import common.names;
import common.utils;

import crypto.Certificate;
import crypto.CertificateManager;
import crypto.CryptoPassword;
import crypto.KeyStore;

import net.Uri;

import web.ResponseIn;
import web.WebApp;
import web.WebService;

import web.http.HostInfo;

import xenia.HttpHandler;
import xenia.HttpServer;

/**
 * The module for basic hosting functionality.
 */
service HostManager(HttpServer httpServer, Directory accountsDir, ProxyManager proxyManager)
        implements common.HostManager {

    @Inject Clock clock;

    /**
     * The HttpServer that should be used by the manager.
     */
    private HttpServer httpServer;

    /**
     * The "accounts" directory.
     */
    private Directory accountsDir;

    /**
     * The proxy manager.
     */
    private ProxyManager proxyManager;

    /**
     * Deployed AppHosts keyed by the deployment name.
     */
    private Map<String, AppHost> deployedHosts = new HashMap();

    /**
     * The key store name to use.
     */
    static String KeyStoreName = "keystore.p12";


    // ----- common.HostManager API ----------------------------------------------------------------

    @Override
    WebApp challengeApp.get() {
        assert Module webApp := challenge.isModuleImport(), webApp.is(WebApp);
        return webApp;
    }

    @Override
    Directory ensureAccountHomeDirectory(String accountName) {
        import ecstasy.fs.DirectoryFileStore;

        Directory accountDir = utils.ensureAccountHomeDirectory(accountsDir, accountName);

        // make sure there is no way for them to get any higher that their "root" directory
        return new DirectoryFileStore(accountDir.ensure()).root;
    }

    @Override
    conditional AppHost getHost(String deployment) {
        return deployedHosts.get(deployment);
    }

    @Override
    void removeHost(AppHost host) {

        host.deactivate(True);

        if (host.is(WebHost)) {
            // leave the webapp stub active
            addStubRoute(host.account, host.appInfo, host.pwd);
        }

        try {
            host.close();
        } catch (Exception ignore) {}

        deployedHosts.remove(host.appInfo?.deployment) : assert;
    }

    // ----- WebApp management ---------------------------------------------------------------------

    @Override
    conditional Certificate ensureCertificate(String accountName, WebAppInfo appInfo,
                                              CryptoPassword pwd, Log errors) {
        (Directory homeDir, Boolean newHome) =
                ensureDeploymentHomeDirectory(accountName, appInfo.deployment);

        String  hostName = appInfo.hostName;
        File    store    = homeDir.fileFor(KeyStoreName);
        Boolean newStore = !store.exists;

        try {
            if (!newStore) {
                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                CheckValid:
                if (Certificate cert := keystore.getCertificate(hostName)) {
                    if (appInfo.provider != "self" &&
                            cert.issuer.splitMap().getOrDefault("CN", "") == hostName) {
                        // the current certificate is self-issued; replace with a real one
                        break CheckValid;
                    }

                    @Inject Clock clock;
                    Int daysLeft = (cert.lifetime.upperBound - clock.now.date).days;
                    if (daysLeft < 14) {
                        // less than two weeks left - renew the certificate
                        break CheckValid;
                    }
                    return True, cert;
                }
            }

            // create or renew the certificate
            @Inject(opts=appInfo.provider) CertificateManager manager;
            if (newStore) {
                // create a new store with a cookie encryption key
                manager.createSymmetricKey(store, pwd, names.CookieEncryptionKey);
            }

            // use the host name as a name for the certificate
            String dName = CertificateManager.distinguishedName(hostName, org=accountName);
            manager.createCertificate(store, pwd, hostName, dName);

            @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;
            assert Certificate cert := keystore.getCertificate(hostName), cert.valid;

            log(homeDir, $|{newStore ? "Created" : "Renewed"} a certificate for "{hostName}"
                          );
            proxyManager.updateProxyConfig^(keystore, pwd, hostName, hostName, &log(homeDir));
            return True, cert;
        } catch (Exception e) {
            try {
                if (newStore) {
                    store.delete();
                }

                Boolean keepLogs = True; // TODO soft code?
                if (newHome && !keepLogs) {
                    homeDir.deleteRecursively();
                }
            } catch (Exception ignore) {}

            errors.add($"Error: Failed to obtain a certificate for {hostName.quoted()}: {e.message}");
            return False;
        }
    }

    @Override
    void addStubRoute(String accountName, WebAppInfo appInfo, CryptoPassword? pwd = Null) {
        Directory homeDir  = ensureDeploymentHomeDirectory(accountName, appInfo.deployment);
        File      store    = homeDir.fileFor(KeyStoreName);
        String    hostName = appInfo.hostName;

        import challenge.AcmeChallenge;
        import stub.Unavailable;
        HttpHandler.CatalogExtras extras =
            [
            AcmeChallenge = () -> new AcmeChallenge(homeDir.dirFor(".challenge").ensure()),
            Unavailable   = () -> new Unavailable(["%deployment%"=hostName]),
            ];

        assert Module stubApp := stub.isModuleImport(), stubApp.is(WebApp);

        HttpHandler handler = new HttpHandler(new HostInfo(hostName), stubApp, extras);
        if (store.exists && pwd != Null) {
            try {
                @Inject("keystore", opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                httpServer.addRoute(hostName, handler, keystore,
                    tlsKey=hostName, cookieKey=names.CookieEncryptionKey);
                return;
            } catch (Exception ignore) {}
        } else {
            httpServer.addRoute(hostName, handler);
        }
    }

    @Override
    conditional WebHost createWebHost(String accountName, WebAppInfo webAppInfo, CryptoPassword pwd,
                                      Log errors) {
        if (deployedHosts.contains(webAppInfo.deployment)) {
            errors.add($|Info: Deployment "{webAppInfo.deployment}" is already active
                      );
            return False;
        }

        Directory libDir   = ensureAccountLibDirectory(accountName);
        Directory buildDir = ensureAccountBuildDirectory(accountName);

        ModuleRepository repository = getRepository(libDir, buildDir);

        String    deployment = webAppInfo.deployment;
        Directory homeDir    = ensureDeploymentHomeDirectory(accountName, deployment);
        File      store      = homeDir.fileFor(KeyStoreName);

        KeyStore keystore;
        try {
            @Inject("keystore", opts=new KeyStore.Info(store.contents, pwd)) KeyStore ks;
            keystore = ks;
        } catch (Exception e) {
            errors.add($|Error: {store.exists ? "Corrupted" : "Missing"} keystore: "{store}"; \
                        |application "{deployment}" for account "{accountName}" needs to be redeployed
                      );
            return False;
        }

        String   hostName = webAppInfo.hostName;
        HostInfo route    = new HostInfo(hostName);

        // by convention, the "root" directory for ACME challenges is a ".challenge" sub-directory
        // of the directory containing the keystore itself, which in our case is `homeDir`
        import challenge.AcmeChallenge;
        HttpHandler.CatalogExtras extras =
            [
            AcmeChallenge = () -> new AcmeChallenge(homeDir.dirFor(".challenge").ensure())
            ];

        common.HostManager mgr = &this.maskAs(common.HostManager);
        WebHost webHost = new WebHost(mgr, route, accountName, repository, webAppInfo, pwd, extras,
                            homeDir, buildDir);
        deployedHosts.put(deployment, webHost);
        httpServer.addRoute(hostName, webHost, keystore,
                tlsKey=hostName, cookieKey=names.CookieEncryptionKey);

        return True, webHost;
    }

    conditional DbHost[] collectSharedDBs(String accountName, ModuleRepository repository,
                                          WebAppInfo webAppInfo, Log errors) {
        String         moduleName = webAppInfo.moduleName;
        ModuleTemplate mainModule;
        try {
            // we need the resolved module to look up annotations
            mainModule = repository.getResolvedModule(moduleName);
        } catch (Exception e) {
            errors.add($"Error: Failed to resolve module: {moduleName.quoted()}: {e.message}");
            return False;
        }

        String[] sharedDBs = webAppInfo.sharedDBs; // deployment names
        try {
            return True, new DbHost[sharedDBs.size](i -> {
                String deployment = sharedDBs[i];
                assert AppHost host := getHost(deployment) as $"Deployment {deployment.quoted()} is not active";
                assert host.is(DbHost) as $"Deployment {deployment.quoted()} is not a DB";
                return host;
                });
        } catch (Exception e) {
            errors.add($"Error: {e.message}");
            return False;
        }
    }

    @Override
    void removeWebDeployment(String accountName, WebAppInfo webAppInfo, CryptoPassword pwd) {
        // remove the deployment data
        Directory homeDir  = ensureDeploymentHomeDirectory(accountName, webAppInfo.deployment);
        File      store    = homeDir.ensure().fileFor(KeyStoreName);
        String    hostName = webAppInfo.hostName;

        try {
            // revoke the certificate (in case of a future hostName reuse)
            if (store.exists) {
                @Inject CertificateManager manager;
                manager.revokeCertificate(store, pwd, hostName);
                store.delete();
            }
        } catch (Exception ignore) {}

        Boolean keepLogs = True; // TODO soft code?

        removeFiles(homeDir, keepLogs);

        proxyManager.removeProxyConfig^(hostName, keepLogs ? &log(homeDir) : (_) -> {});
    }


    // ----- DbApp management ----------------------------------------------------------------------

    @Override
    conditional DbHost createDbHost(String accountName, DbAppInfo dbAppInfo, Log errors) {
        Directory libDir   = ensureAccountLibDirectory(accountName);
        Directory buildDir = ensureAccountBuildDirectory(accountName);

        ModuleRepository repository = getRepository(libDir, buildDir);

        String    deployment = dbAppInfo.deployment;
        Directory homeDir    = ensureDeploymentHomeDirectory(accountName, deployment);

        if (DbHost dbHost := utils.createDbHost(repository, dbAppInfo.moduleName, dbAppInfo, "jsondb",
                homeDir, buildDir, errors)) {
            deployedHosts.put(deployment, dbHost);
            return True, dbHost;
        }
        return False;
    }

    @Override
    void removeDbDeployment(String accountName, DbAppInfo dbAppInfo) {
        // remove the deployment data
        Directory homeDir = ensureDeploymentHomeDirectory(accountName, dbAppInfo.deployment);

        removeFiles(homeDir, keepLogs = True); // TODO soft code?
    }


    // ----- lifecycle -----------------------------------------------------------------------------

    @Override
    Boolean shutdown(Boolean force = False) {
        Boolean reschedule = False;
        for (AppHost host : deployedHosts.values) {
            reschedule |= !host.deactivate(True);
        }

        if (reschedule && !force) {
            return False;
        }

        for (AppHost host : deployedHosts.values) {
            host.close();
        }
        return True;
    }

    /**
     * Log the specified message to the application "console" file.
     */
    void log(Directory homeDir, String message) {
        homeDir.fileFor("console.log").ensure().append($"\n{clock.now}: {message}".utf8());
    }


    // ----- helpers -------------------------------------------------------------------------------

    private ModuleRepository getRepository(Directory libDir, Directory buildDir) {
        @Inject("repository") ModuleRepository coreRepo;

        ModuleRepository[] baseRepos  = [coreRepo, new DirRepository(libDir), new DirRepository(buildDir)];
        return new LinkedRepository(baseRepos.freeze(True));
    }

    private void removeFiles(Directory dir, Boolean keepLogs) {
        if (dir.exists) {
            if (keepLogs) {
                for (File file : dir.filesRecursively()) {
                    if (!file.name.endsWith(".log")) {
                        file.delete();
                    }
                // TODO: remove empty directories
                }
            } else {
                dir.deleteRecursively();
            }
        }
    }
}