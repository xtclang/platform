import ecstasy.mgmt.Container.InjectionKey;
import ecstasy.mgmt.Container.Linker;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.WebAppInfo;

import common.utils;

import crypto.CryptoPassword;

import web.*;
import web.responses.SimpleResponse;

/**
 * Dedicated service for operations on WebApps.
 */
@WebService("/webapp")
@LoginRequired
service WebAppEndpoint
        extends CoreService {

    /**
     * Return a JSON map of all webapps for all webapps for given account.
     */
    @Get("status")
    Map<String, WebAppInfo> checkStatus() {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            HashMap<String, WebAppInfo> status = new HashMap();
            for ((String deployment, WebAppInfo info) : accountInfo.webApps) {
                if (WebHost webHost := hostManager.getWebHost(deployment)) {
                    info = info.updateStatus(webHost.active);
                }
                status.put(deployment, info.redact());
            }
            return status.freeze(inPlace=True);
        }
        return [];
    }

    /**
     * Handle a request to register a webapp for a module.
     * Assumptions:
     *  - many webapps can be registered from the same module with a different deployment
     *  - a deployment has one and only one webapp
     */
    @Post("/register/{deployment}/{moduleName}")
    SimpleResponse register(String deployment, String moduleName) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(Unauthorized, $"Account '{accountName}' is missing");
        }

        // compute the full host name (e.g. "welcome.localhost.xqiz.it")
        String hostName = $"{deployment}.{baseDomain}";

        if (hostName.equals(httpServer.bindAddr) || accountInfo.webApps.contains(deployment)) {
            return new SimpleResponse(Conflict, $"Deployment already exists: '{deployment}'");
        }

        if (!accountInfo.modules.contains(moduleName)) {
            return new SimpleResponse(NotFound, $"Module is missing: '{moduleName}'");
        }

        // create a random password to be used to access the webapp's keystore
        @Inject Random random;
        String         encrypted = accountManager.encrypt(random.int128().toString());
        CryptoPassword cryptoPwd = accountManager.decrypt(encrypted);

        ErrorLog errors = new ErrorLog();
        if (!hostManager.ensureCertificate(accountName, deployment, hostName, cryptoPwd, errors)) {
            return new SimpleResponse(Conflict, errors.collectErrors());
        }

        accountManager.addOrUpdateWebApp(accountName,
                new WebAppInfo(deployment, moduleName, hostName, encrypted, False));

        // the deployment has been registered, but not yet started; give them something better
        // than "404: Page Not Found" to look at
        ControllerConfig.addStubRoute(hostName);
        return new SimpleResponse(OK);
    }

    /**
     * Collect an array of injections necessary for the specified deployment,
     */
    @Get("/injections/{deployment}")
    SimpleResponse injections(String deployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
        ModuleRepository accountRepo = utils.getModuleRepository(libDir);
        ModuleTemplate   mainModule;
        try {
            mainModule = accountRepo.getResolvedModule(appInfo.moduleName);
        } catch (Exception e) {
            return new SimpleResponse(Conflict, $"Failed to load module: {appInfo.moduleName.quoted()}");
        }

        @Inject Linker linker;
        InjectionKey[] injections = linker.collectInjections(mainModule);

        import json.JsonArray;
        JsonArray destringable = new JsonArray();

        for (InjectionKey key : injections) {
            if (key.type.isA(Destringable)) {
                destringable += Map:["name"=key.name, "type"=key.type.toString()];
            }
        }

        String jsonString = json.Printer.DEFAULT.render(destringable);
        return new SimpleResponse(OK, Json, bytes=jsonString.utf8());
    }

    /**
     * Retrieve an injection value.
     */
    @Get("/injections/{deployment}/{name}")
    SimpleResponse getInjectionValue(String deployment, String name) {
        TODO
    }

    /**
     * Store an injection value.
     */
    @Put("/injections/{deployment}/{name}/{value}")
    SimpleResponse setInjectionValue(String deployment, String name, @BodyParam String value) {
        TODO
    }

    /**
     * Remove an injection value.
     */
    @Delete("/injections/{deployment}/{name}")
    SimpleResponse deleteInjectionValue(String deployment, String name) {
        TODO
    }

    /**
     * Handle a request to unregister a deployment.
     */
    @Delete("/unregister/{deployment}")
    SimpleResponse unregister(String deployment) {
        SimpleResponse response = stopWebApp(deployment);
        if (response.status != OK) {
            return response;
        }

        if (WebHost webHost := hostManager.getWebHost(deployment)) {
            hostManager.removeWebHost(webHost);
        }

        hostManager.removeDeployment(accountName, deployment);
        accountManager.removeWebApp(accountName, deployment);

        return new SimpleResponse(OK);
    }

    /**
     * Handle a request to start a deployment.
     */
    @Post("/start/{deployment}")
    SimpleResponse startWebApp(String deployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        ErrorLog errors = new ErrorLog();
        WebHost  webHost;
        if (!(webHost := hostManager.getWebHost(deployment))) {
            // create a new WebHost
            if (!(webHost := hostManager.createWebHost(httpServer, accountName, appInfo,
                    accountManager.decrypt(appInfo.password), errors))) {
                return new SimpleResponse(Conflict, errors.collectErrors());
            }
        }

        if (webHost.activate(True, errors)) {
            accountManager.addOrUpdateWebApp(accountName, appInfo.updateStatus(True));
            return new SimpleResponse(OK);
        } else {
            hostManager.removeWebHost(webHost);
            webHost.deactivate(True);
            return new SimpleResponse(Conflict, errors.collectErrors());
        }
    }

    /**
     * Show the app console's content.
     */
    @Get("appLog/{deployment}")
    @Produces(Text)
    String report(String deployment) {
        if (WebHost webHost := hostManager.getWebHost(deployment)) {
            File consoleFile = webHost.homeDir.fileFor("console.log");
            if (consoleFile.exists && consoleFile.size > 0) {
                return consoleFile.contents.unpackUtf8();
            }
        }
        return "[empty]";
    }

    /**
     * Handle a request to stop a deployment.
     */
    @Post("/stop/{deployment}")
    SimpleResponse stopWebApp(String deployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        WebHost webHost;
        if (!(webHost := hostManager.getWebHost(deployment))) {
            if (appInfo.active) {
                // there's no host, but the deployment is marked as active; fix it
                accountManager.addOrUpdateWebApp(accountName, appInfo.updateStatus(False));
                }
            return new SimpleResponse(OK, "The application is not running");
        }

        webHost.deactivate(True);
        accountManager.addOrUpdateWebApp(accountName, appInfo.updateStatus(False));
        return new SimpleResponse(OK);
    }

    // ----- helper methods ------------------------------------------------------------------------

    /**
     * Get a WebAppInfo for the specified deployment.
     */
    (WebAppInfo | SimpleResponse) getWebInfo(String deployment) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(NotFound, $"Account '{accountName}' is missing");
        }

        if (WebAppInfo appInfo := accountInfo.webApps.get(deployment)) {
            return appInfo;
        }
        return new SimpleResponse(NotFound, $"Unknown deployment '{deployment}'");
    }
}