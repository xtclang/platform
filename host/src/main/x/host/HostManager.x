import ecstasy.mgmt.Container;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import ecstasy.text.Log;

import common.AppHost;
import common.WebHost;

import common.model.WebModuleInfo;

import common.utils;

import crypto.KeyStore;


/**
 * The module for basic hosting functionality.
 */
service HostManager
        implements common.HostManager {
    // ----- properties ------------------------------------------------------------------------------------------------

    /**
     * Loaded WebHost objects keyed by the application domain name.
     */
    Map<String, WebHost> loaded = new HashMap();


    // ----- common.HostManager API ------------------------------------------------------------------------------------

    @Override
    conditional WebHost getWebHost(String domain) {
        return loaded.get(domain);
    }

    @Override
    conditional WebHost ensureWebHost(Directory userDir, WebModuleInfo webInfo, Log errors) {
        import xenia.tools.ModuleGenerator;

        Directory libDir;
        if (!(libDir := userDir.findDir("lib"))) {
            errors.add($"Error: \"{userDir}/lib\" directory not found");
            return False;
        }

        Directory buildDir = userDir.dirFor("build").ensure();

        @Inject("repository") ModuleRepository coreRepo;

        ModuleRepository[] baseRepos  = [coreRepo, new DirRepository(libDir), new DirRepository(buildDir)];
        ModuleRepository   repository = new LinkedRepository(baseRepos.freeze(True));
        ModuleTemplate     mainModule;
        try {
            mainModule = repository.getResolvedModule(webInfo.name); // TODO GG: why do we need the resolved module?
        } catch (Exception e) {
            errors.add($|Error: Failed to resolve the module: "{webInfo.name}" ({e.text})
                      );
            return False;
        }

        String moduleName = mainModule.qualifiedName;
        try {
            if (!mainModule.findAnnotation("web.WebApp")) {
                errors.add($"Module \"{moduleName}\" is not a WebApp");
                return False;
            }

            ModuleGenerator generator = new ModuleGenerator(moduleName);
            if (ModuleTemplate hostTemplate := generator.ensureWebModule(repository, buildDir, errors)) {
                Directory appHomeDir = utils.ensureHome(userDir, mainModule.qualifiedName);

                if ((Container container, AppHost[] dependents) :=
                        utils.createContainer(repository, hostTemplate, appHomeDir, False, errors)) {
                    KeyStore keystore = getKeyStore(userDir);

                    Tuple result = container.invoke("createServer_",
                        Tuple:(webInfo.hostName, webInfo.bindAddr, webInfo.httpPort, webInfo.httpsPort, keystore));

                    function void() shutdown = result[0].as(function void());

                    WebHost webHost = new WebHost(container, webInfo, appHomeDir, shutdown, dependents);
                    loaded.put(webInfo.domain, webHost);

                    File consoleFile = appHomeDir.fileFor("console.log");
                    consoleFile.append(errors.toString().utf8());

                    return True, webHost;
                }
            } else {
                errors.add($"Error: Failed to create a Web host for {moduleName.quoted()}");
            }
        } catch (Exception e) {
            @Inject Console console;
            console.print(e); // TODO GG: remove
            errors.add($"Error: Failed to create a host for {moduleName.quoted()}; reason={e.text}");
        }

        return False;
    }

    @Override
    void removeWebHost(WebHost webHost) {
        loaded.remove(webHost.info.domain);
    }

    @Override
    void shutdown() {
        for (WebHost webHost : loaded.values) {
            webHost.close();
        }
    }

    /**
     * Get the KeyStore.
     */
    KeyStore getKeyStore(Directory userDir) {
        // TODO: retrieve from the db
        @Inject(opts=new KeyStore.Info(userDir.fileFor("certs.p12").contents, "password"))
        KeyStore keystore;
        return keystore;
    }
}