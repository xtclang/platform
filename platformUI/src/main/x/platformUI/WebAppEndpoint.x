import ecstasy.mgmt.ModuleRepository;

import common.AppHost;
import common.DbHost;
import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.DbAppInfo;
import common.model.InjectionKey;
import common.model.Injections;
import common.model.ModuleInfo;
import common.model.WebAppInfo;

import common.utils;

import crypto.Certificate;
import crypto.CryptoPassword;

import net.IPAddress;
import net.Uri;

import web.*;
import web.responses.SimpleResponse;

/**
 * Dedicated service for operations on WebApps.
 */
@WebService("/apps")
@LoginRequired
service WebAppEndpoint
        extends CoreService {

    // ---- generic app end-points -----------------------------------------------------------------

    /**
     * Return a JSON map of all deployments for a given account.
     */
    @Get("/deployments")
    Map<String, AppInfo> checkStatus() {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            HashMap<String, AppInfo> status = new HashMap();
            for ((String deployment, AppInfo appInfo) : accountInfo.apps) {
                status.put(deployment, appInfo.with(active=isActive(deployment)).redact());
            }
            return status.freeze(inPlace=True);
        }
        return [];
    }

    /**
     * Get an AppInfo for the specified deployment.
     */
    @Get("/deployments{/deployment}")
    (AppInfo | SimpleResponse) checkStatus(String deployment) {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        return appInfo.is(SimpleResponse)
                ? appInfo
                : appInfo.with(active=isActive(deployment)).redact();
    }

    /**
     * Get the stats for a deployment.
     */
    @Get("/stats{/deployment}")
    (String | SimpleResponse) getUseCount(String deployment) {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        if (AppHost host := hostManager.getHost(deployment)) {
            switch (host.is(_)) {
            case DbHost:
                return host.active ? $"Active; {host.dependees} users" : "Inactive";
            case WebHost:
                return $|{host.active ? "Active" : "Inactive"}; {host.totalRequests} \
                        |processed requests
                        ;
            default:
                return $"Unknown deployment type for {host}";
            }
        } else {
            return "Not deployed";
        }
    }

    /**
     * Handle a request to unregister a deployment and remove all the associated data.
     */
    @Delete("/deployments{/deployment}")
    SimpleResponse unregisterApp(String deployment) {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        if (AppHost host := hostManager.getHost(deployment)) {
            hostManager.removeHost(host);
        }

        if (appInfo.is(WebAppInfo)) {
            httpServer.removeRoute(appInfo.hostName);

            hostManager.removeWebDeployment(
                accountName, appInfo, accountManager.decrypt(appInfo.password));
        } else {
            assert appInfo.is(DbAppInfo);

            hostManager.removeDbDeployment(accountName, appInfo);
        }

        accountManager.removeApp(accountName, deployment);

        return new SimpleResponse(OK);
    }

    /**
     * Collect an array of injections necessary for the specified deployment,
     */
    @Get("/injections{/deployment}")
    SimpleResponse injections(String deployment) {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
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
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        InjectionKey|String key = appInfo.findKey(name, type);
        if (key.is(String)) {
            return new SimpleResponse(Conflict, key);
        }

        assert String value := appInfo.injections.get(key);
        return new SimpleResponse(OK, value);
    }

    /**
     * Store an injection value.
     */
    @Put("/injections{/deployment}{/name}{/type}")
    SimpleResponse setInjectionValue(String deployment, String name, @BodyParam String value,
                                     String type = "") {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        InjectionKey|String key = appInfo.findKey(name, type);
        if (key.is(String)) {
            return new SimpleResponse(Conflict, key);
        }

        Injections injections = appInfo.injections.put(key, value);
        appInfo = appInfo.with(injections=injections);
        accountManager.addOrUpdateApp(accountName, appInfo);

        if (AppHost host := hostManager.getHost(deployment)) {
            // update the webHost - the new injections value will take effect upon re-activation
            host.appInfo = appInfo;
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
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        InjectionKey|String key = appInfo.findKey(name, type);
        if (key.is(String)) {
            return new SimpleResponse(Conflict, key);
        }

        Injections injections = appInfo.injections.remove(key);
        accountManager.addOrUpdateApp(accountName, appInfo.with(injections=injections));
        return new SimpleResponse(OK);
    }

    /**
     * Handle a request to start a deployment.
     */
    @Post("/start{/deployment}")
    (AppInfo | SimpleResponse) startApp(String deployment) {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        // make sure all injections are specified
        if (appInfo.injections.values.any(v -> v == "")) {
            return new SimpleResponse(Conflict, "Unspecified injections");
        }

        ErrorLog errors = new ErrorLog();
        AppHost  host;
        if (appInfo.is(WebAppInfo)) {

            CreateWebHost:
            if (!(host := hostManager.getWebHost(deployment))) {
                CryptoPassword pwd = accountManager.decrypt(appInfo.password);

                // at this point the application is registered, therefore there is an active stub route
                if (hostManager.ensureCertificate(accountName, appInfo, pwd, errors),
                    host := hostManager.createWebHost(accountName, appInfo, pwd, errors)) {
                        break CreateWebHost;
                    }
                return new SimpleResponse(Conflict, errors.collectErrors());
            }
        } else {
            assert appInfo.is(DbAppInfo);

            if (!(host := hostManager.getDbHost(deployment))) {
               if (!(host := hostManager.createDbHost(accountName, appInfo, errors))) {
                    return new SimpleResponse(Conflict, errors.collectErrors());
               }
            }
        }

        if (host.activate(True, errors)) {
            appInfo = appInfo.with(autoStart=True);
            accountManager.addOrUpdateApp(accountName, appInfo);
            return appInfo.redact();
        } else {
            hostManager.removeHost(host);
            return new SimpleResponse(Conflict, errors.collectErrors());
        }
    }

    /**
     * Handle a request to stop a deployment.
     */
    @Post("/stop{/deployment}")
    SimpleResponse stopApp(String deployment) {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        if (AppHost host := hostManager.getHost(deployment)) {
            hostManager.removeHost(host);
            accountManager.addOrUpdateApp(accountName, appInfo.with(autoStart=False));
            return new SimpleResponse(OK);
        } else {
            if (appInfo.autoStart) {
                // there's no host, but the deployment is marked as `autoStart`; fix it
                accountManager.addOrUpdateApp(accountName, appInfo.with(autoStart=False));
                }
            return new SimpleResponse(OK, "The application is not active");
        }
    }

    /**
     * Show the app console's content.
     */
    @Get("/logs{/deployment}{/dbName}")
    @Produces(Text)
    String report(String deployment, String dbName = "") {
        (AppInfo|SimpleResponse) appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return "[unknown]";
        }

        Directory homeDir = hostManager.ensureDeploymentHomeDirectory(accountName, appInfo.deployment);
        if (dbName != "") {
            homeDir = homeDir.dirFor(dbName);
        }
        File console = homeDir.fileFor("console.log");
        if (console.exists && console.size > 0) {
            return console.contents.unpackUtf8();
        }
        return "[empty]";
    }


    // ---- Web app end-points ---------------------------------------------------------------------

    /**
     * Handle a request to register a web app for a module.
     * Assumptions:
     *  - many apps can be registered from the same module with a different deployment
     *  - a deployment has one and only one app
     */
    @Put("/web{/deployment}{/moduleName}{/provider}")
    (AppInfo | SimpleResponse) registerWebApp(String deployment, String moduleName,
                                              String provider = "self") {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(NotFound, $"Account '{accountName}' is missing");
        }

        if (String error := reportInvalidName(deployment)) {
            return new SimpleResponse(BadRequest,
                $"Invalid deployment name {deployment.quoted()}: {error}");
        }

        // compute the full host name (e.g. "welcome.localhost.xqiz.it")
        String hostName = $"{deployment}.{baseDomain}".toLowercase();

        if (httpServer.routes.keys.any(route -> route.host.toString() == hostName) ||
                accountInfo.apps.contains(deployment)) {
            return new SimpleResponse(Conflict, $"Deployment already exists: '{deployment}'");
        }

        if (!accountInfo.modules.contains(moduleName)) {
            return new SimpleResponse(NotFound, $"Module is missing: '{moduleName}'");
        }

        Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
        ModuleRepository accountRepo = utils.getModuleRepository(libDir);
        Injections       injections;

        // the deployment cannot be active until all injections are specified
        if (InjectionKey[] injectionKeys := utils.collectDestringableInjections(accountRepo, moduleName)) {
            if (injectionKeys.empty) {
                injections = [];
            } else {
                injections = new ListMap();
                for (InjectionKey key : injectionKeys) {
                    injections.put(key, "");
                }
            }
        } else {
            return new SimpleResponse(Conflict, $"Failed to load module: {moduleName.quoted()}");
        }

        // create a random password to be used to access the webapp's keystore
        @Inject Random random;
        String         encrypted = accountManager.encrypt(random.uint128().toString());
        CryptoPassword cryptoPwd = accountManager.decrypt(encrypted);

        WebAppInfo appInfo = new WebAppInfo(
                deployment, moduleName, hostName, encrypted, provider, injections=injections);

        // the deployment is not active; the "stub" will serve the ACME protocol challenge requests
        // as well as give them something better than "HttpStatus 404: Page Not Found" to look at
        hostManager.addStubRoute(accountName, appInfo, cryptoPwd);

        ErrorLog errors = new ErrorLog();
        if (!hostManager.ensureCertificate(accountName, appInfo, cryptoPwd, errors)) {
            httpServer.removeRoute(hostName);
            return new SimpleResponse(Conflict, errors.collectErrors());
        }

        accountManager.addOrUpdateApp(accountName, appInfo);

        return appInfo.redact();
    }

    /**
     * Handle a request to renew the certificate.
     */
    @Post("/renew{/deployment}{/provider}")
    SimpleResponse renewCertificate(String deployment, String provider = "self") {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        if (provider != appInfo.provider) {
            appInfo = appInfo.with(provider=provider);
        }

        CryptoPassword pwd   = accountManager.decrypt(appInfo.password);
        ErrorLog      errors = new ErrorLog();

        if (Certificate cert := hostManager.ensureCertificate(accountName, appInfo, pwd, errors)) {
            accountManager.addOrUpdateApp(accountName, appInfo);
            return new SimpleResponse(OK, cert.toString());
        } else {
            return new SimpleResponse(Conflict, errors.collectErrors());
        }
    }

    /**
     * Mark a dependent DB module as "shared".
     */
    @Put("/shared{/deployment}{/dbDeployment}")
    (AppInfo | SimpleResponse) markShared(String deployment, String dbDeployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        assert AccountInfo accountInfo := accountManager.getAccount(accountName);
        Map<String, ModuleInfo> modules = accountInfo.modules;

        assert ModuleInfo webModuleInfo := modules.get(appInfo.moduleName);

        if (DbHost dbHost := hostManager.getDbHost(dbDeployment)) {
            String dbModuleName = dbHost.moduleName;
            if (!webModuleInfo.dependsOn(dbModuleName)) {
                return new SimpleResponse(Conflict,
                    $|Deployment: "{deployment}" does not have a dependency on the database \
                    |"{dbModuleName}"
                    );
            }

            if (hostManager.getWebHost(deployment)) {
                return new SimpleResponse(Conflict,
                    $|Deployment: "{deployment}" is currently active and needs to be stopped
                    );
            }

            String[] sharedDBs = appInfo.sharedDBs;
            if (!sharedDBs.contains(dbDeployment)) {
                sharedDBs += dbDeployment;
            }
            appInfo = appInfo.with(sharedDBs=sharedDBs);
            accountManager.addOrUpdateApp(accountName, appInfo);
            return appInfo.redact();
        } else {
            return new SimpleResponse(Conflict,
                $"Unknown dependent module deployment: {dbDeployment.quoted()}");
        }
    }

    /**
     * Unmark a dependent DB module as "shared".
     */
    @Delete("/shared{/deployment}{/dbDeployment}")
    (AppInfo | SimpleResponse) unmarkShared(String deployment, String dbDeployment) {
        (WebAppInfo|SimpleResponse) appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        if (hostManager.getWebHost(deployment)) {
            return new SimpleResponse(Conflict,
                $|Deployment: "{deployment}" is currently active and needs to be stopped
                );
        }

        String[] sharedDBs = appInfo.sharedDBs;
        if (sharedDBs.contains(dbDeployment)) {
            sharedDBs = sharedDBs.remove(dbDeployment);
            appInfo = appInfo.with(sharedDBs=sharedDBs);
            accountManager.addOrUpdateApp(accountName, appInfo);
            return appInfo.redact();
        } else {
            return new SimpleResponse(Conflict,
                $"Unknown dependent module deployment: {dbDeployment.quoted()}");
        }
    }


    // ---- Db app end-points ----------------------------------------------------------------------

    /**
     * Handle a request to register a db app for a module. REVIEW: merge with registerWebApp?
     */
    @Put("/db{/deployment}{/moduleName}")
    (AppInfo | SimpleResponse) registerDbApp(String deployment, String moduleName) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(Unauthorized, $"Account '{accountName}' is missing");
        }

        if (String error := reportInvalidName(deployment)) {
            return new SimpleResponse(BadRequest,
                $"Invalid deployment name {deployment.quoted()}: {error}");
        }

        if (!accountInfo.modules.contains(moduleName)) {
            return new SimpleResponse(NotFound, $"Module is missing: '{moduleName}'");
        }

        Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
        ModuleRepository accountRepo = utils.getModuleRepository(libDir);
        Injections       injections;

        // the deployment cannot be active until all injections are specified
        if (InjectionKey[] injectionKeys := utils.collectDestringableInjections(accountRepo, moduleName)) {
            if (injectionKeys.empty) {
                injections = [];
            } else {
                injections = new ListMap();
                for (InjectionKey key : injectionKeys) {
                    injections.put(key, "");
                }
            }
        } else {
            return new SimpleResponse(Conflict, $"Failed to load module: {moduleName.quoted()}");
        }

        DbAppInfo appInfo = new DbAppInfo(deployment, moduleName, injections=injections);

        accountManager.addOrUpdateApp(accountName, appInfo);

        return appInfo.redact();
    }


    // ----- helper methods ------------------------------------------------------------------------

    /**
     * Get an AppInfo for the specified deployment.
     */
    (AppInfo | SimpleResponse) getAppInfo(String deployment) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(NotFound, $"Account '{accountName}' is missing");
        }

        if (AppInfo appInfo := accountInfo.apps.get(deployment)) {
            return appInfo;
        }
        return new SimpleResponse(NotFound, $"Unknown deployment '{deployment}'");
    }

    /**
     * Get a WebAppInfo for the specified deployment.
     */
    (WebAppInfo | SimpleResponse) getWebInfo(String deployment) {
        (AppInfo | SimpleResponse) appInfo = getAppInfo(deployment);

        return appInfo.is(WebAppInfo | SimpleResponse)
                ? appInfo
                : new SimpleResponse(NotFound, $"Deployment '{deployment}' is not a WebApp");
    }

    /**
     * Get a DbAppInfo for the specified deployment.
     */
    (DbAppInfo | SimpleResponse) getDbInfo(String deployment) {
        (AppInfo | SimpleResponse) appInfo = getAppInfo(deployment);

        return appInfo.is(DbAppInfo | SimpleResponse)
                ? appInfo
                : new SimpleResponse(NotFound, $"Deployment '{deployment}' is not a DbApp");
    }

    /**
     * @return True iff the specified deployment is active (in memory)
     */
    Boolean isActive(String deployment) {
        if (AppHost host := hostManager.getHost(deployment)) {
            return host.active;
        }
        return False;
    }

    /**
     * Check if the specified name could be used as a part of the "authority" section of the Uri.
     *
     * @param name  the new domain name
     *
     * @return True iff the name is invalid
     * @return (conditional) the error message
     */
    static conditional String reportInvalidName(String name) {
        if (name.endsWith('.')) {
            return True, "Name cannot end with a dot";
        }

        @Volatile String? error = Null;
        if ((String? user, String? host, IPAddress? ip, UInt16? port) :=
                Uri.parseAuthority(name, (e) -> {error = e;})) {
            if (user != Null || host == Null || port != Null) {
                error = "Invalid host name";
            } else if (ip != Null) {
                error = "IP is not allowed";
            }
        }
        return error == Null ? False : (True, error);
    }
}