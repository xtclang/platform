import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.InjectionKey;
import common.model.Injections;
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
    @Get("/status")
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
     * Get a WebAppInfo for the specified deployment.
     */
    @Get("/status{/deployment}")
    (WebAppInfo | SimpleResponse) checkStatus(String deployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        return appInfo.is(SimpleResponse)
                ? appInfo
                : appInfo.redact();
    }

    /**
     * Handle a request to register a webapp for a module.
     * Assumptions:
     *  - many webapps can be registered from the same module with a different deployment
     *  - a deployment has one and only one webapp
     */
    @Post("/register{/deployment}{/moduleName}")
    (WebAppInfo | SimpleResponse) register(String deployment, String moduleName) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(Unauthorized, $"Account '{accountName}' is missing");
        }

        // compute the full host name (e.g. "welcome.localhost.xqiz.it")
        String hostName = $"{deployment}.{baseDomain}";

        if (httpServer.routes.keys.any(route -> route.host.toString() == hostName) ||
                accountInfo.webApps.contains(deployment)) {
            return new SimpleResponse(Conflict, $"Deployment already exists: '{deployment}'");
        }

        if (!accountInfo.modules.contains(moduleName)) {
            return new SimpleResponse(NotFound, $"Module is missing: '{moduleName}'");
        }

        Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
        ModuleRepository accountRepo = utils.getModuleRepository(libDir);
        InjectionKey[]   injectionKeys;
        if (!(injectionKeys := utils.collectDestringableInjections(accountRepo, moduleName))) {
            return new SimpleResponse(Conflict, $"Failed to load module: {moduleName.quoted()}");
        }

        // create a random password to be used to access the webapp's keystore
        @Inject Random random;
        String         encrypted = accountManager.encrypt(random.int128().toString());
        CryptoPassword cryptoPwd = accountManager.decrypt(encrypted);

        ErrorLog errors = new ErrorLog();
        if (!hostManager.ensureCertificate(accountName, deployment, hostName, cryptoPwd, errors)) {
            return new SimpleResponse(Conflict, errors.collectErrors());
        }

        Injections injections = [];
        if (!injectionKeys.empty) {
            injections = new ListMap();
            for (InjectionKey key : injectionKeys) {
                injections.put(key, "");
            }
        }
        WebAppInfo appInfo =
                new WebAppInfo(deployment, moduleName, hostName, encrypted, False, injections);
        accountManager.addOrUpdateWebApp(accountName, appInfo);

        // the deployment has been registered, but not yet started; give them something better
        // than "HttpStatus 404: Page Not Found" to look at
        ControllerConfig.addStubRoute(hostName);
        return appInfo.redact();
    }

    /**
     * Collect an array of injections necessary for the specified deployment,
     */
    @Get("/injections{/deployment}")
    SimpleResponse injections(String deployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        import json.JsonArray;
        JsonArray keys = new JsonArray();

        for (InjectionKey key : appInfo.injections.keys) {
            keys += Map:["name"=key.name, "type"=key.type];
        }

        String jsonString = json.Printer.DEFAULT.render(keys);
        return new SimpleResponse(OK, Json, bytes=jsonString.utf8());
    }

    /**
     * Retrieve an injection value.
     */
    @Get("/injections{/deployment}{/name}{/type}")
    SimpleResponse getInjectionValue(String deployment, String name, String type = "") {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }
        InjectionKey key;
        if (type == "") {
            if (!(key := appInfo.uniqueKey(name))) {
                return new SimpleResponse(Conflict, $"Injection name {name.quoted()} is not unique");
            }
        } else {
            key = new InjectionKey(name, type);
        }

        if (String value := appInfo.injections.get(key)) {
            return new SimpleResponse(OK, value);
        } else {
            return new SimpleResponse(NotFound);
        }
    }

    /**
     * Store an injection value.
     */
    @Put("/injections{/deployment}{/name}{/type}")
    SimpleResponse setInjectionValue(String deployment, String name, @BodyParam String value,
                                     String type = "") {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        InjectionKey key;
        if (type == "") {
            if (!(key := appInfo.uniqueKey(name))) {
                return new SimpleResponse(Conflict, $"Injection name {name.quoted()} is not unique");
            }
        } else {
            key = new InjectionKey(name, type);
        }

        Injections injections = appInfo.injections.put(key, value);
        appInfo = appInfo.with(injections=injections);
        accountManager.addOrUpdateWebApp(accountName, appInfo);

        if (WebHost webHost := hostManager.getWebHost(deployment)) {
            // update the webHost - the new injections value will take effect upon re-activation
            webHost.appInfo = appInfo;
        }
        return new SimpleResponse(OK);
    }

    /**
     * Remove an injection value.
     *
     * This operation is quite destructive; the application may stop working properly.
     */
    @Delete("/injections{/deployment}{/name}{/type}")
    SimpleResponse deleteInjectionValue(String deployment, String name, String type = "") {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        InjectionKey key;
        if (type == "") {
            if (!(key := appInfo.uniqueKey(name))) {
                return new SimpleResponse(Conflict, $"Injection name {name.quoted()} is not unique");
            }
        } else {
            key = new InjectionKey(name, type);
        }

        Injections injections = appInfo.injections.remove(key);
        accountManager.addOrUpdateWebApp(accountName, appInfo.with(injections=injections));
        return new SimpleResponse(OK);
    }

    /**
     * Handle a request to unregister a deployment.
     */
    @Delete("/unregister{/deployment}")
    SimpleResponse unregister(String deployment) {
        SimpleResponse response = stopWebApp(deployment);
        if (response.status != OK) {
            return response;
        }

        removeWebHost(deployment);

        hostManager.removeDeployment(accountName, deployment);
        accountManager.removeWebApp(accountName, deployment);

        return new SimpleResponse(OK);
    }

    /**
     * Handle a request to start a deployment.
     */
    @Post("/start{/deployment}")
    (WebAppInfo | SimpleResponse) startWebApp(String deployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        ErrorLog errors = new ErrorLog();
        WebHost  webHost;
        if (!(webHost := hostManager.getWebHost(deployment))) {
            // make sure all injections are specified
            if (appInfo.injections.values.any(v -> v == "")) {
                return new SimpleResponse(Conflict, "Unspecified injections");
            }
            // create a new WebHost
            if (!(webHost := hostManager.createWebHost(httpServer, accountName, appInfo,
                    accountManager.decrypt(appInfo.password), errors))) {
                return new SimpleResponse(Conflict, errors.collectErrors());
            }
        }

        if (webHost.activate(True, errors)) {
            appInfo = appInfo.updateStatus(True);
            accountManager.addOrUpdateWebApp(accountName, appInfo);
            return appInfo.redact();
        } else {
            hostManager.removeWebHost(httpServer, webHost);
            webHost.deactivate(True);
            return new SimpleResponse(Conflict, errors.collectErrors());
        }
    }

    /**
     * Handle a request to stop a deployment.
     */
    @Post("/stop{/deployment}")
    SimpleResponse stopWebApp(String deployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        if (removeWebHost(deployment)) {
            accountManager.addOrUpdateWebApp(accountName, appInfo.updateStatus(False));

            // leave the webapp stub active
            ControllerConfig.addStubRoute(appInfo.hostName);
            return new SimpleResponse(OK);
        } else {
            if (appInfo.active) {
                // there's no host, but the deployment is marked as active; fix it
                accountManager.addOrUpdateWebApp(accountName, appInfo.updateStatus(False));
                }
            return new SimpleResponse(OK, "The application is not active");
        }
    }

    /**
     * Show the app console's content.
     */
    @Get("appLog{/deployment}")
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

    /**
     * Stop a WebHost for the specified deployment.
     *
     * @return True iff the WebHost existed; False otherwise
     */
    Boolean removeWebHost(String deployment) {
        if (WebHost webHost := hostManager.getWebHost(deployment)) {
            webHost.deactivate(True);
            hostManager.removeWebHost(httpServer, webHost);
            return True;
            }
        return False;
    }
}