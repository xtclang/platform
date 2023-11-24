import ecstasy.mgmt.Container;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;
import ecstasy.reflect.TypeTemplate;

import ecstasy.text.Log;

import common.AppHost;
import common.WebHost;

import common.model.WebAppInfo;

import common.utils;

import crypto.KeyStore;


/**
 * The module for basic hosting functionality.
 */
service HostManager (Directory usersDir, KeyStore keystore)
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
     * Active WebHosts keyed by the deployment name.
     */
    private Map<String, WebHost> activeWebHosts = new HashMap();


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
        return activeWebHosts.get(deployment);
    }

    @Override
    conditional WebHost createWebHost(String accountName, WebAppInfo webAppInfo, Log errors) {
        if (activeWebHosts.contains(webAppInfo.deployment)) {
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
        ModuleTemplate     mainModule;
        try {
            // we need the resolved module to look up annotations
            mainModule = repository.getResolvedModule(webAppInfo.moduleName);
        } catch (Exception e) {
            errors.add($|Error: Failed to resolve module: "{webAppInfo.moduleName}": {e.message}
                      );
            return False;
        }

        String moduleName = mainModule.qualifiedName;
        try {
            if (!utils.isWebModule(mainModule)) {
                errors.add($|Error: Module "{moduleName}" is not a WebApp
                          );
                return False;
            }

            import xenia.tools.ModuleGenerator;

            ModuleGenerator generator = new ModuleGenerator(mainModule);
            if (ModuleTemplate hostTemplate := generator.ensureWebModule(repository, buildDir, errors)) {
                Directory appHomeDir = hostDir.dirFor(webAppInfo.deployment).ensure();

                if ((Container container, AppHost[] dependencies) :=
                        utils.createContainer(repository, hostTemplate, appHomeDir, buildDir, False, errors)) {
                    KeyStore keystore = getKeyStore(userDir);

                    Tuple result = container.invoke("createServer_",
                        Tuple:(webAppInfo.hostName, webAppInfo.httpPort, webAppInfo.httpsPort,
                               keystore));

                    function void() shutdown = result[0].as(function void());

                    WebHost webHost = new WebHost(container, webAppInfo, appHomeDir, shutdown, dependencies);
                    activeWebHosts.put(webAppInfo.deployment, webHost);

                    webHost.log(errors.toString());

                    return True, webHost;
                }
            } else {
                errors.add($"Error: Failed to create a Web host for {moduleName.quoted()}");
            }
        } catch (Exception e) {
            errors.add($"Error: {e.message}");
        }

        return False;
    }

    @Override
    void removeWebHost(WebHost webHost) {
        webHost.close();
        activeWebHosts.remove(webHost.info.deployment);
    }

    @Override
    void shutdown() {
        for (WebHost webHost : activeWebHosts.values) {
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