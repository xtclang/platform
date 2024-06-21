import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.text.Log;

import common.WebHost;

import common.model.WebAppInfo;

import common.names;
import common.utils;

import convert.formats.Base64Format;

import crypto.Certificate;
import crypto.CertificateManager;
import crypto.CryptoPassword;
import crypto.KeyStore;

import net.Uri;

import web.Client;
import web.HttpClient;
import web.ResponseIn;
import web.WebApp;
import web.WebService;

import web.http.HostInfo;

import xenia.HttpHandler;
import xenia.HttpServer;

/**
 * The module for basic hosting functionality.
 */
service HostManager(Directory accountsDir, Uri[] receivers)
        implements common.HostManager {

    /**
     * The "accounts" directory.
     */
    private Directory accountsDir;

    /**
     * The receivers associated with proxy servers.
     */
    private Uri[] receivers;

    /**
     * Deployed WebHosts keyed by the deployment name.
     */
    private Map<String, WebHost> deployedWebHosts = new HashMap();

    /**
     * The client used to talk to external services.
     */
    @Lazy Client client.calc() = new HttpClient();

    /**
     * The key store name to use.
     */
    static String KeyStoreName = "keystore.p12";


    // ----- common.HostManager API ----------------------------------------------------------------

    @Override
    Directory ensureAccountHomeDirectory(String accountName) {
        import ecstasy.fs.DirectoryFileStore;

        Directory accountDir = utils.ensureAccountHomeDirectory(accountsDir, accountName);

        // make sure there is no way for them to get any higher that their "root" directory
        return new DirectoryFileStore(accountDir.ensure()).root;
    }

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
                            cert.issuer.splitMap().getOrDefault("CN", "") == appInfo.hostName) {
                        // the current certificate is self-issued; replace with a real one
                        break CheckValid;
                    }

                    @Inject Clock clock;
                    Int daysLeft = (cert.lifetime.upperBound - clock.now.date).days;
                    if (appInfo.provider == "self" || daysLeft < 14) {
                        // self-issued or less than two weeks left - renew the certificate
                        break CheckValid;
                    }
                    // TODO: there's probably no reason to update the receivers; need to figure out
                    //       a way to optimize this out
                    updateProxyConfig(hostName, keystore, pwd);
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
            updateProxyConfig(hostName, keystore, pwd);
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

    /**
     * For every proxy, there might be a receiver associated with it. Send the corresponding
     * updates.
     */
    private void updateProxyConfig(String hostName, KeyStore keystore, CryptoPassword pwd) {
        @Inject CertificateManager manager;

        for (Uri receiverUri : receivers) {
            Byte[] bytes  = manager.extractKey(keystore, pwd, hostName);
            String pemKey = $|-----BEGIN PRIVATE KEY-----
                             |{Base64Format.Instance.encode(bytes, pad=True, lineLength=64)}
                             |-----END PRIVATE KEY-----
                             |
                             ;
            ResponseIn response = client.put(
                    receiverUri.with(path=$"/nginx/{hostName}/key"), pemKey, Text);

            if (response.status == OK) {
                StringBuffer pemCert = new StringBuffer();
                for (Certificate cert : keystore.getCertificateChain(hostName)) {
                    pemCert.append(
                            $|-----BEGIN CERTIFICATE-----
                             |{Base64Format.Instance.encode(cert.toDerBytes(), pad=True, lineLength=64)}
                             |-----END CERTIFICATE-----
                             |
                             );
                }
                response = client.put(
                    receiverUri.with(path=$"/nginx/{hostName}/cert"), pemCert.toString(), Text);
            }
            if (response.status != OK) {
                @Inject Console console;
                console.print($"Failed to update proxy {receiverUri}");
            }
        }
    }

    @Override
    void addStubRoute(HttpServer httpServer, String accountName, WebAppInfo appInfo,
                      CryptoPassword? pwd = Null) {
        Directory homeDir  = ensureDeploymentHomeDirectory(accountName, appInfo.deployment);
        File      store    = homeDir.fileFor(KeyStoreName);
        String    hostName = appInfo.hostName;

        assert Module stubApp := stub.isModuleImport(), stubApp.is(WebApp);

        HttpHandler.CatalogExtras extras =
            [
            stub.Unavailable   = () -> new stub.Unavailable(["%deployment%"=hostName]),
            stub.AcmeChallenge = () -> new stub.AcmeChallenge(homeDir.dirFor(".challenge").ensure())
            ];

        HttpHandler handler = new HttpHandler(new HostInfo(hostName), stubApp, extras);
        if (store.exists && pwd != Null) {
            try {
                @Inject("keystore", opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                httpServer.addRoute(hostName, handler, keystore,
                    tlsKey=hostName, cookieKey=names.CookieEncryptionKey);
                return;
            } catch (Exception ignore) {}
        }
        httpServer.addRoute(hostName, handler);
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

        Directory libDir   = ensureAccountLibDirectory(accountName);
        Directory buildDir = ensureAccountBuildDirectory(accountName);

        @Inject("repository") ModuleRepository coreRepo;

        ModuleRepository[] baseRepos  = [coreRepo, new DirRepository(libDir), new DirRepository(buildDir)];
        ModuleRepository   repository = new LinkedRepository(baseRepos.freeze(True));

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
        HttpHandler.CatalogExtras extras =
            [
            stub.AcmeChallenge = () -> new stub.AcmeChallenge(homeDir.dirFor(".challenge").ensure())
            ];

        WebHost webHost = new WebHost(route, repository, accountName, webAppInfo, pwd, extras,
                                      homeDir, buildDir);
        deployedWebHosts.put(deployment, webHost);
        httpServer.addRoute(hostName, webHost, keystore,
                tlsKey=hostName, cookieKey=names.CookieEncryptionKey);

        return True, webHost;
    }

    @Override
    void removeWebHost(HttpServer httpServer, WebHost webHost) {
        // leave the webapp stub active
        addStubRoute(httpServer, webHost.account, webHost.appInfo, webHost.pwd);

        try {
            webHost.close();
        } catch (Exception ignore) {}

        deployedWebHosts.remove(webHost.appInfo.deployment);
    }

    @Override
    void removeDeployment(String accountName, String deployment,
                          String hostName, CryptoPassword pwd) {
        // remove the deployment data
        Directory homeDir = ensureDeploymentHomeDirectory(accountName, deployment);
        File      store   = homeDir.ensure().fileFor(KeyStoreName);

        try {
            // revoke the certificate (in case of a future hostName reuse)
            if (store.exists) {
                @Inject CertificateManager manager;
                manager.revokeCertificate(store, pwd, hostName);
                store.delete();
            }
        } catch (Exception ignore) {}

        // notify the receivers
        for (Uri receiverUri : receivers) {
            client.delete(receiverUri.with(path=$"/nginx/{hostName}"));
        }

        Boolean keepLogs = True; // TODO soft code?
        if (homeDir.exists) {
            if (keepLogs) {
//                TODO GG: implement filesRecursively()
//                for (File file : homeDir.filesRecursively()) {
//                    if (!file.name.endsWith(".log")) {
//                        file.delete();
//                    }
                // TODO: remove empty directories
            } else {
                homeDir.deleteRecursively();
            }
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
}