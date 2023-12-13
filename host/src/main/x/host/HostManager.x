import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.text.Log;

import common.WebHost;

import common.model.WebAppInfo;

import common.utils;

import crypto.KeyStore;

import xenia.HttpServer;


/**
 * The module for basic hosting functionality.
 */
service HostManager(Directory usersDir, KeyStore keystore)
        implements common.HostManager {
    // ----- properties ------------------------------------------------------------------------------------------------

    /**
     * The "users" directory.
     */
    private Directory usersDir;

    /**
     * TEMPORARY: For now the platform keystore is shared by all web apps.
     */
    private KeyStore keystore;

    /**
     * Deployed WebHosts keyed by the deployment name.
     */
    private Map<String, WebHost> deployedWebHosts = new HashMap();


    // ----- common.HostManager API ------------------------------------------------------------------------------------

    @Override
    Directory ensureUserLibDirectory(String accountName) {
        import ecstasy.fs.DirectoryFileStore;

        Directory userDir = ensureUserDirectory(accountName);

        // make sure there is no way for them to get any higher that the "lib" directory
        return new DirectoryFileStore(userDir.dirFor("lib").ensure()).root;
    }

    @Override
    conditional WebHost getWebHost(String deployment) {
        return deployedWebHosts.get(deployment);
    }

    @Override
    conditional WebHost createWebHost(String accountName, WebAppInfo webAppInfo, Log errors) {
        if (deployedWebHosts.contains(webAppInfo.deployment)) {
                errors.add($|Info: Deployment "{webAppInfo.deployment}" is already active
                          );
            return False;
        }

        Directory userDir  = ensureUserDirectory(accountName);
        Directory libDir   = userDir.dirFor("lib").ensure();
        Directory buildDir = userDir.dirFor("build").ensure();
        Directory hostDir  = userDir.dirFor("host").ensure();

        @Inject("repository") ModuleRepository coreRepo;

        ModuleRepository[] baseRepos  = [coreRepo, new DirRepository(libDir), new DirRepository(buildDir)];
        ModuleRepository   repository = new LinkedRepository(baseRepos.freeze(True));

        @Inject HttpServer server;
        try {
            server.configure(webAppInfo.hostName, webAppInfo.httpPort, webAppInfo.httpsPort,
                             getKeyStore(userDir));

            String    deployment = webAppInfo.deployment;
            Directory homeDir    = hostDir.dirFor(deployment).ensure();
            WebHost   webHost    = new WebHost(server, repository, webAppInfo, homeDir, buildDir);

            server.start(webHost);
            deployedWebHosts.put(deployment, webHost);

            return True, webHost;
        } catch (Exception e) {
            errors.add($"Error: {e.message}");
            return False;
        }
    }

    @Override
    void removeWebHost(WebHost webHost) {
        try {
            webHost.close();
        } catch (Exception ignore) {}

        deployedWebHosts.remove(webHost.info.deployment);
    }

    @Override
    void shutdown() {
        for (WebHost webHost : deployedWebHosts.values) {
            webHost.close();
        }
    }


    /**
     * Ensure the user directory for the specified account.
     */
    private Directory ensureUserDirectory(String accountName) {
        // TODO: validate/convert the name
        return usersDir.dirFor(accountName).ensure();
    }

    /**
     * Get the KeyStore.
     */
    private KeyStore getKeyStore(Directory userDir) = keystore;
}