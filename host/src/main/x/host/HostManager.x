import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.text.Log;

import common.WebHost;

import common.model.WebAppInfo;

import common.utils;

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

        String    deployment = webAppInfo.deployment;
        Directory homeDir    = hostDir.dirFor(deployment).ensure();
        WebHost   webHost    = new WebHost(repository, accountName, webAppInfo, homeDir, buildDir);

        deployedWebHosts.put(deployment, webHost);

        return True, webHost;
    }

    @Override
    void removeWebHost(WebHost webHost) {
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
}