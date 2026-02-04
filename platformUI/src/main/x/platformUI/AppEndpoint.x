import ecstasy.mgmt.ModuleRepository;

import common.AppHost;
import common.DbHost;
import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.DbAppInfo;
import common.model.IdpInfo;
import common.model.InjectionKey;
import common.model.Injections;
import common.model.ModuleInfo;
import common.model.WebAppInfo;

import common.names;
import common.utils;

import crypto.Certificate;
import crypto.CryptoPassword;
import crypto.Decryptor;

import json.JsonObject;

import net.IPAddress;

import web.*;
import web.responses.SimpleResponse;

/**
 * Dedicated service for operations on WebApps and DbApps.
 */
@WebService("/apps")
@LoginRequired
@SessionRequired
service AppEndpoint
        extends CoreService {

    typedef (AppInfo | SimpleResponse)    as AppResponse;
    typedef (WebAppInfo | SimpleResponse) as WebResponse;

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
    AppResponse checkStatus(String deployment) {
        AppResponse appInfo = getAppInfo(deployment);
        return appInfo.is(SimpleResponse)
                ? appInfo
                : appInfo.with(active=isActive(deployment)).redact();
    }

    /**
     * Set an AppInfo attribute for the specified deployment.
     */
    @Put("/deployments{/deployment}")
    AppResponse changeInfo(String deployment,
            @QueryParam Boolean? autoStart  = Null,
            @QueryParam Boolean? useCookies = Null,
            @QueryParam Boolean? useAuth    = Null,
            ) {
        AppResponse appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        Boolean update = False;
        if (autoStart != Null && appInfo.autoStart != autoStart) {
            appInfo = appInfo.with(autoStart=autoStart);
            update  = True;
        }
        if (appInfo.is(WebAppInfo)) {
            if (useCookies != Null && appInfo.useCookies != useCookies) {
                appInfo = appInfo.with(useCookies=useCookies);
                update  = True;
            }
            if (useAuth != Null && appInfo.useAuth != useAuth) {
                appInfo = appInfo.with(useAuth=useAuth);
                update  = True;
            }
        }

        if (update) {
            accountManager.addOrUpdateApp(accountName, appInfo);
        }
        return appInfo.redact();
    }

    /**
     * Set up an OAuth provider and the corresponding secrets.
     *
     * The client must append "Base64(clientId):Base64(clientSecret)" as a message body.
     */
    @Post("deployments{/deployment}/providers{/provider}")
    @LoginRequired
    AppResponse ensureAuthProvider(String deployment, String provider, @BodyParam String secrets) {

        assert Int delim := secrets.indexOf(':') as "Invalid secrets format";

        String clientId     = secrets[0 ..< delim];
        String clientSecret = secrets.substring(delim+1);

        // decode from Base64 representation
        import conv.formats.Base64Format;
        clientId     = Base64Format.Instance.decode(clientId).unpackUtf8();
        clientSecret = Base64Format.Instance.decode(clientSecret).unpackUtf8();

        return ensureAuthProvider(deployment, provider, clientId, clientSecret);
    }

    /**
     * Internal implementation of "ensureAuthProvider" endpoint.
     */
    AppResponse ensureAuthProvider(String deployment, String provider,
                                   String clientId, String clientSecret) {
        WebResponse appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        Directory      homeDir    = hostManager.ensureDeploymentHomeDirectory(accountName, deployment);
        File           store      = homeDir.fileFor(names.KeyStoreName);
        CryptoPassword storePwd   = accountManager.decrypt(appInfo.password);
        @Inject("keystore", opts=new KeyStore.Info(store.contents, storePwd)) KeyStore keystore;

        Decryptor decryptor = utils.createDecryptor(keystore);

        // encode for storage using the application's secrets decryptor
        IdpInfo info = new IdpInfo(clientId, utils.encrypt(decryptor, clientSecret));
        appInfo = appInfo.with(idProviders=appInfo.idProviders.put(provider, info));

        accountManager.addOrUpdateApp(accountName, appInfo);
        return appInfo.redact();
    }

    /**
     * Get the stats for a deployment.
     */
    @Get("/stats{/deployment}")
    (JsonObject | SimpleResponse) getStats(String deployment) {
        AppResponse appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        JsonObject stats = json.newObject();
        if (AppHost host := hostManager.getHost(deployment)) {
            stats["deployed"] = True;
            stats["active"]   = host.active;
            stats["storage"]  = utils.storageSize(host.homeDir).toIntLiteral();

            switch (host.is(_)) {
            case DbHost:
                if (host.active) {
                    stats["users"] = host.dependees.toIntLiteral();
                }
                break;
            case WebHost:
                if (host.active) {
                    stats["requests"] = host.totalRequests.toIntLiteral();
                }
                break;
            default:
                return new SimpleResponse(NotFound, $"Unknown deployment type for {host}");
            }
        } else {
            stats["deployed"] = False;
        }
        return stats.makeImmutable();
    }

    /**
     * Handle a request to unregister a deployment and remove all the associated data.
     */
    @Delete("/deployments{/deployment}")
    SimpleResponse unregisterApp(String deployment) {
        AppResponse appInfo = getAppInfo(deployment);
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
        AppResponse appInfo = getAppInfo(deployment);
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
        AppResponse appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        InjectionKey|String key = appInfo.findKey(name, type);
        if (key.is(String)) {
            return new SimpleResponse(Conflict, key);
        }

        return new SimpleResponse(OK, appInfo.injections.get(key) ?: assert);
    }

    /**
     * Store an injection value.
     */
    @Put("/injections{/deployment}{/name}{/type}")
    SimpleResponse setInjectionValue(String deployment, String name, @BodyParam String value,
                                     String type = "") {
        AppResponse appInfo = getAppInfo(deployment);
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
        AppResponse appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        InjectionKey|String key = appInfo.findKey(name, type);
        if (key.is(String)) {
            return new SimpleResponse(Conflict, key);
        }

        Injections injections = appInfo.injections.put(key, "");
        accountManager.addOrUpdateApp(accountName, appInfo.with(injections=injections));
        return new SimpleResponse(OK);
    }

    /**
     * Handle a request to start a deployment.
     */
    @Post("/start{/deployment}")
    AppResponse startApp(String deployment) {
        AppResponse appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        // make sure all injections are specified
        if (val entry := appInfo.injections.entries.any(e -> e.value == "")) {
            return new SimpleResponse(Conflict, $"Unspecified injection: {entry.key.name.quoted()}");
        }

        ErrorLog errors = new ErrorLog();
        AppHost  host;
        if (appInfo.is(WebAppInfo)) {

            CreateWebHost:
            if (!(host := hostManager.getWebHost(deployment))) {
                CryptoPassword storePwd = accountManager.decrypt(appInfo.password);

                // at this point the application is registered, therefore there is an active stub route
                if (hostManager.ensureCertificate(accountName, appInfo, storePwd, errors),
                    host := hostManager.createWebHost(accountName, appInfo, storePwd, errors)) {
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
        AppResponse appInfo = getAppInfo(deployment);
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
        AppResponse appInfo = getAppInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return "[unknown]";
        }

        Directory homeDir = hostManager.ensureDeploymentHomeDirectory(accountName, deployment);
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
    AppResponse registerWebApp(String deployment, String moduleName,
                                              String provider = "self") {

        (Injections | SimpleResponse) injections = prepareRegister(deployment, moduleName);
        if (injections.is(SimpleResponse)) {
            return injections;
        }

        // compute the full host name (e.g. "welcome.localhost.xqiz.it")
        String hostName = $"{deployment}.{baseDomain}".toLowercase();

        if (httpServer.routes.keys.any(route -> route.host.toString() == hostName)) {
            return new SimpleResponse(Conflict, $"Deployment already exists: '{deployment}'");
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
        WebResponse appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        Boolean changeProvider = False;
        if (provider != appInfo.provider) {
            changeProvider = True;
            appInfo        = appInfo.with(provider=provider);
        }

        CryptoPassword storePwd = accountManager.decrypt(appInfo.password);
        ErrorLog       errors   = new ErrorLog();

        if (Certificate cert := hostManager.ensureCertificate(accountName, appInfo, storePwd,
                                    errors, force=changeProvider)) {
            if (changeProvider) {
                accountManager.addOrUpdateApp(accountName, appInfo);
            }
            return new SimpleResponse(OK, cert.toString());
        } else {
            return new SimpleResponse(Conflict, errors.collectErrors());
        }
    }

    /**
     * Mark a dependent DB module as "shared".
     */
    @Put("/shared{/deployment}{/dbDeployment}")
    AppResponse markShared(String deployment, String dbDeployment) {
        WebResponse appInfo = getWebInfo(deployment);
        if (appInfo.is(SimpleResponse)) {
            return appInfo;
        }

        (DbAppInfo|SimpleResponse) dbInfo = getDbInfo(dbDeployment);
        if (dbInfo.is(SimpleResponse)) {
            return dbInfo;
        }

        assert AccountInfo accountInfo   := accountManager.getAccount(accountName);
        assert ModuleInfo  webModuleInfo := accountInfo.modules.get(appInfo.moduleName);

        String dbModuleName = dbInfo.moduleName;
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
    }

    /**
     * Unmark a dependent DB module as "shared".
     */
    @Delete("/shared{/deployment}{/dbDeployment}")
    AppResponse unmarkShared(String deployment, String dbDeployment) {
        WebResponse appInfo = getWebInfo(deployment);
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
     * Handle a request to register a db app for a module.
     */
    @Put("/db{/deployment}{/moduleName}")
    AppResponse registerDbApp(String deployment, String moduleName) {

        (Injections | SimpleResponse) injections = prepareRegister(deployment, moduleName);
        if (injections.is(SimpleResponse)) {
            return injections;
        }

        DbAppInfo appInfo = new DbAppInfo(deployment, moduleName, injections=injections);
        accountManager.addOrUpdateApp(accountName, appInfo);
        return appInfo.redact();
    }

    // ----- helper methods ------------------------------------------------------------------------

    /**
     * Get an AppInfo for the specified deployment.
     */
    AppResponse getAppInfo(String deployment) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(NotFound, $"Account '{accountName}' is missing");
        }

        return accountInfo.apps.get(deployment)?;
        return new SimpleResponse(NotFound, $"Unknown deployment '{deployment}'");
    }

    /**
     * Get a WebAppInfo for the specified deployment.
     */
    WebResponse getWebInfo(String deployment) {
        AppResponse appInfo = getAppInfo(deployment);

        return appInfo.is(WebResponse)
                ? appInfo
                : new SimpleResponse(NotFound, $"Deployment '{deployment}' is not a WebApp");
    }

    /**
     * Get a DbAppInfo for the specified deployment.
     */
    (DbAppInfo | SimpleResponse) getDbInfo(String deployment) {
        AppResponse appInfo = getAppInfo(deployment);

        return appInfo.is(DbAppInfo|SimpleResponse)
                ? appInfo
                : new SimpleResponse(NotFound, $"Deployment '{deployment}' is not a DbApp");
    }

    /**
     * Common preparation steps for a Web- or Db- module registration.
     *
     * @return an `Injections` map or a `SimpleResponse` if an error occurred
     */
    (Injections | SimpleResponse) prepareRegister(String deployment, String moduleName) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(NotFound, $"Account '{accountName}' is missing");
        }

        if (String error := validateDeploymentName(deployment)) {
            return new SimpleResponse(BadRequest,
                $"Invalid deployment name {deployment.quoted()}: {error}");
        }

        ModuleInfo moduleInfo;
        if (!(moduleInfo := accountInfo.modules.get(moduleName))) {
            return new SimpleResponse(NotFound, $"Module is missing: '{moduleName}'");
        }

        if (accountInfo.apps.contains(deployment)) {
            return new SimpleResponse(Conflict, $"Deployment already exists: '{deployment}'");
        }

        Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
        ModuleRepository accountRepo = utils.getModuleRepository(libDir);
        Injections       injections;

        // the deployment cannot be active until all injections are specified
        InjectionKey[] injectionKeys = moduleInfo.injections;
        if (injectionKeys.empty) {
            injections = [];
        } else {
            injections = new ListMap();
            for (InjectionKey key : injectionKeys) {
                injections.put(key, "");
            }
            injections.makeImmutable();
        }
        return injections;
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
     * @param name  the deployment name
     *
     * @return True iff the name is invalid
     * @return (conditional) the error message
     */
    static conditional String validateDeploymentName(String name) {
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