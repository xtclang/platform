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
import crypto.KeyStore;

import xenia.HttpServer;

/**
 * The module for basic hosting functionality.
 */
service HostManager(Directory usersDir)
        implements common.HostManager {

    /**
     * The "users" directory.
     */
    private Directory usersDir;

    /**
     * Deployed WebHosts keyed by the deployment name.
     */
    private Map<String, WebHost> deployedWebHosts = new HashMap();


    // ----- common.HostManager API ----------------------------------------------------------------

    @Override
    Directory ensureUserDirectory(String accountName) {
        import ecstasy.fs.DirectoryFileStore;

        Directory userDir = utils.ensureUserDirectory(usersDir, accountName);

        // make sure there is no way for them to get any higher that their "root" directory
        return new DirectoryFileStore(userDir.ensure()).root;
    }

    @Override
    Boolean ensureCertificate(String accountName, String hostName, Log errors) {
        Directory userDir = utils.ensureUserDirectory(usersDir, accountName);
        File      store   = userDir.fileFor(KeyStoreName);
        String    pwd     = accountName; // TODO: obtain the password from the "master" keystore

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
                                      WebAppInfo webAppInfo, Log errors) {
        if (deployedWebHosts.contains(webAppInfo.deployment)) {
                errors.add($|Info: Deployment "{webAppInfo.deployment}" is already active
                          );
            return False;
        }

        Directory userDir  = utils.ensureUserDirectory(usersDir, accountName);
        Directory libDir   = userDir.dirFor("lib").ensure();
        Directory buildDir = userDir.dirFor("build").ensure();
        Directory hostDir  = userDir.dirFor("host").ensure();

        @Inject("repository") ModuleRepository coreRepo;

        ModuleRepository[] baseRepos  = [coreRepo, new DirRepository(libDir), new DirRepository(buildDir)];
        ModuleRepository   repository = new LinkedRepository(baseRepos.freeze(True));

        String    deployment = webAppInfo.deployment;
        Directory homeDir    = hostDir.dirFor(deployment).ensure();
        WebHost   webHost    = new WebHost(httpServer, repository, accountName, webAppInfo, homeDir, buildDir);

        File   store = userDir.fileFor(KeyStoreName);
        String pwd   = accountName; // TODO: obtain the password from the "master" keystore

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
        if (!ensureCertificate(accountName, hostName, errors)) {
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

        deployedWebHosts.remove(webHost.info.deployment);
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