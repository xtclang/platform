import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.text.Log;

import common.WebHost;

import common.model.WebAppInfo;

import common.names;
import common.utils;

import crypto.Certificate;
import crypto.CertificateManager;
import crypto.CryptoPassword;
import crypto.KeyStore;

import xenia.HttpServer;

/**
 * The module for basic hosting functionality.
 */
service HostManager(Directory accountsDir)
        implements common.HostManager {

    /**
     * The "accounts" directory.
     */
    private Directory accountsDir;

    /**
     * Deployed WebHosts keyed by the deployment name.
     */
    private Map<String, WebHost> deployedWebHosts = new HashMap();


    // ----- common.HostManager API ----------------------------------------------------------------

    @Override
    Directory ensureAccountHomeDirectory(String accountName) {
        import ecstasy.fs.DirectoryFileStore;

        Directory accountDir = utils.ensureAccountHomeDirectory(accountsDir, accountName);

        // make sure there is no way for them to get any higher that their "root" directory
        return new DirectoryFileStore(accountDir.ensure()).root;
    }

    @Override
    Boolean ensureCertificate(String accountName, String deployment, String hostName,
                              CryptoPassword pwd, Log errors) {
        Directory accountDir = utils.ensureAccountHomeDirectory(accountsDir, accountName);
        Directory homeDir    = accountDir.dirFor($"deploy/{deployment}").ensure();
        File      store      = homeDir.fileFor(KeyStoreName);

        try {
            if (store.exists) {
                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                if (Certificate cert := keystore.getCertificate(hostName), cert.valid) {
                    return True;
                }
            }

            // create or renew the certificate
            @Inject CertificateManager manager;

            if (!store.exists) {
                // create a cookie encryption key
                manager.createSymmetricKey(store, pwd, names.CookieEncryptionKey);
            }

            // use the host name as a name for the certificate
            String dName = CertificateManager.distinguishedName(hostName, org=accountName);
            manager.createCertificate(store, pwd, hostName, dName);
            return True;
        } catch (Exception e) {
            errors.add($"Error: Failed to obtain a certificate for {hostName.quoted}: {e.message}");
            return False;
        }
    }

    @Override
    conditional WebHost getWebHost(String deployment) {
        return deployedWebHosts.get(deployment);
    }

    @Override
    conditional WebHost createWebHost(HttpServer httpServer, String accountName,
                                      WebAppInfo webAppInfo, CryptoPassword pwd, Log errors) {
        if (deployedWebHosts.contains(webAppInfo.deployment)) {
                errors.add($|Info: Deployment "{webAppInfo.deployment}" is already active
                          );
            return False;
        }

        Directory accountDir = ensureAccountHomeDirectory(accountName);
        Directory libDir     = ensureAccountLibDirectory(accountName);
        Directory buildDir   = accountDir.dirFor("build").ensure();
        Directory hostDir    = accountDir.dirFor("deploy").ensure();

        @Inject("repository") ModuleRepository coreRepo;

        ModuleRepository[] baseRepos  = [coreRepo, new DirRepository(libDir), new DirRepository(buildDir)];
        ModuleRepository   repository = new LinkedRepository(baseRepos.freeze(True));

        String    deployment = webAppInfo.deployment;
        Directory homeDir    = hostDir.dirFor(deployment).ensure();
        WebHost   webHost    = new WebHost(httpServer, repository, accountName, webAppInfo, homeDir, buildDir);

        File     store = homeDir.fileFor(KeyStoreName);
        KeyStore keystore;
        try {
            @Inject("keystore", opts=new KeyStore.Info(store.contents, pwd)) KeyStore ks;
            keystore = ks;
        } catch (Exception e) {
            errors.add($|Error: {store.exists ? "Corrupted" : "Missing"} keystore: "{store}";\
                        | application "{deployment}" for account "{accountName}" needs to be redeployed
                      );
            return False;
        }

        String hostName = webAppInfo.hostName;
        if (!ensureCertificate(accountName, deployment, hostName, pwd, errors)) {
            return False;
        }

        deployedWebHosts.put(deployment, webHost);

        httpServer.addRoute(hostName, webHost, keystore, hostName, names.CookieEncryptionKey);

        return True, webHost;
    }

    @Override
    void removeWebHost(WebHost webHost) {
        webHost.httpServer.removeRoute(webHost.info.hostName);

        try {
            webHost.close();
        } catch (Exception ignore) {}

        String deployment = webHost.info.deployment;

        deployedWebHosts.remove(deployment);

        Directory accountDir = utils.ensureAccountHomeDirectory(accountsDir, webHost.account);
        Directory homeDir    = accountDir.dirFor($"deploy/{deployment}");
        if (homeDir.exists) {
            homeDir.deleteRecursively();
        }
    }

    @Override
    Boolean shutdown(Boolean force = False) {
        Boolean reschedule = False;
        for (WebHost webHost : deployedWebHosts.values) {
            reschedule |= webHost.deactivate(True);
        }

        if (reschedule) {
            return False;
        }

        for (WebHost webHost : deployedWebHosts.values) {
            webHost.close();
        }
        return True;
    }


    // ----- helpers -------------------------------------------------------------------------------

    static String KeyStoreName = "keystore.p12";
}