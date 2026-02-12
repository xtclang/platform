import json.*;
import web.*;
import web.responses.SimpleResponse;

import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.ModuleInfo;
import common.model.IdpInfo;
import common.model.InjectionKey;
import common.model.Injections;
import common.model.WebAppInfo;

import AppEndpoint.AppResponse;

/**
 * New API for project (deployment) management.
 */
@WebService("/api/v1/projects")
@LoginRequired
@SessionRequired
service Projects
        extends CoreService {

    AppEndpoint delegate.get() {
        private @Lazy AppEndpoint delegate_.calc() = new AppEndpoint();

        AppEndpoint delegate = delegate_;
        delegate.request = this.request;
        return delegate;
    }

    // TODO: very temporary; remove
    @Options("{/path*}")
    @SessionOptional
    @LoginOptional
    HttpStatus preflight() = OK;

    @Get("/")
    JsonArray getProjects() {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        Map<String, AppInfo> deployments = accountInfo.apps;

        JsonArrayBuilder response = json.arrayBuilder();
        for (AppInfo info : deployments.values) {
            response.add(toJsonObject(info));
        }
        return response.build();
    }

    @Get("{/id}")
    JsonObject|HttpStatus getProject(String id) {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        if (AppInfo info := accountInfo.apps.get(id)) {
            return toJsonObject(info);
        } else {
            return NotFound;
        }
    }

    @Post("/")
    JsonObject registerApp(@BodyParam JsonObject projectInfo) {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        String  deployment = projectInfo["name"].as(String);
        String  moduleName = projectInfo["module"].as(String);
        String? provider   = projectInfo["certProvider"].as(String?);

        (Injections | SimpleResponse) result = delegate.prepareRegister(deployment, moduleName);
        if (result.is(SimpleResponse)) {
            return toJsonObject(result);
        }
        assert ModuleInfo moduleInfo := accountInfo.modules.get(moduleName);

        AppResponse appInfo;
        if (moduleInfo.kind == Web) {
            if (provider == Null || provider.empty) {
                provider = "certbot";
            }
            appInfo = delegate.registerWebApp(deployment, moduleName, provider);
        } else if (moduleInfo.kind == Db) {
            appInfo = delegate.registerDbApp(deployment, moduleName);

        } else {
            appInfo = new SimpleResponse(Conflict, "Unsupported project type");
        }

        if (appInfo.is(SimpleResponse)) {
            return toJsonObject(appInfo);
        }
        return updateApp(deployment, projectInfo);
    }

    @Patch("{/id}")
    JsonObject updateApp(String id, @BodyParam JsonObject projectInfo) {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        AppResponse appInfo = delegate.getAppInfo(id);
        if (appInfo.is(SimpleResponse)) {
            return toJsonObject(appInfo);
        }

        String?     provider   = projectInfo["certProvider"].as(String?);
        JsonObject? injections = projectInfo["injections"].as(JsonObject?);

        if (injections != Null) {
            for ((Doc key, Doc value) : injections) {
                SimpleResponse response = delegate.setInjectionValue(
                    id, key.as(String), value.as(String));
                if (response.status != OK) {
                    return toJsonObject(response);
                }
            }
        }

        if (appInfo.is(WebAppInfo) && provider != Null && appInfo.provider != provider) {
            SimpleResponse response = delegate.renewCertificate(id, provider);
            if (response.status != OK) {
                return toJsonObject(response);
            }
        }
        appInfo = delegate.getAppInfo(id);
        return toJsonObject(appInfo.as(AppInfo));
    }

    @Delete("{/id}")
    SimpleResponse deleteProject(String id) {
        return delegate.unregisterApp(id);
    }

    @Patch("{/id}/oauth-providers{/provider}")
    JsonObject ensureAuthProvider(String id, String provider, @BodyParam JsonObject secrets) {

        String clientId     = secrets["clientId"].as(String);
        String clientSecret = secrets["clientSecret"].as(String);

        AppResponse appInfo = delegate.ensureAuthProvider(id, provider, clientId, clientSecret);
        if (appInfo.is(SimpleResponse)) {
            return toJsonObject(appInfo);
        }
        return toJsonObject(appInfo.as(AppInfo));
    }

    /**
     * Find all projects that have the specified module as it's primary module or depend on it.
     */
    @Get("{?usesModule}")
    JsonArray findProjectsByModule(@QueryParam("usesModule") String moduleName) {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        Map<String, ModuleInfo> modules     = accountInfo.modules;
        Map<String, AppInfo>    deployments = accountInfo.apps;

        JsonArrayBuilder response = json.arrayBuilder();
        for (AppInfo appInfo : deployments.values) {
            if (appInfo.moduleName == moduleName) {
                response.add(toJsonObject(appInfo));
            } else {
                assert ModuleInfo moduleInfo := modules.get(appInfo.moduleName);
                if (moduleInfo.dependencies.any(rm -> rm.name == moduleName)) {
                    response.add(toJsonObject(appInfo));
                }
            }
        }
        return response.build();
    }

    @Post("/{id}/start")
    JsonObject start(String id) {
        AppResponse appInfo = delegate.startApp(id);
        if (appInfo.is(SimpleResponse)) {
            return toJsonObject(appInfo);
        }
        return toJsonObject(appInfo);
    }

    @Post("/{id}/stop")
    JsonObject stop(String id) {
        SimpleResponse result = delegate.stopApp(id);
        if (result.status == OK) {
            AppResponse appInfo = delegate.getAppInfo(id);
            if (appInfo.is(AppInfo)) {
                return toJsonObject(appInfo);
            } else {
                result = appInfo;
            }
        }
        return toJsonObject(result);
    }

    JsonObject toJsonObject(AppInfo info) {
        JsonObjectBuilder project    = json.objectBuilder();
        String            deployment = info.deployment;
        project.addAll([
            "id"        = deployment,
            "name"      = deployment,
            "module"    = info.moduleName,
            "autoStart" = info.autoStart,
            "active"    = delegate.isActive(deployment),
            "restart"   = delegate.isRestartRequired(deployment),
        ]);

        if (info.is(WebAppInfo)) {
            project.addAll([
                "kind"         = "web",
                "url"          = info.hostName,
                "sharedDbs"    = info.sharedDBs,
                "certProvider" = info.provider,
                "useCookies"   = info.useCookies,
                "useAuth"      = info.useAuth,
            ]);

            JsonObjectBuilder idProviders = json.objectBuilder();
            for ((String key, IdpInfo value) : info.idProviders) {
                idProviders.add(key,
                    ["clientId"=value.clientId, "clientSecret"=value.redact().clientSecret]);
            }
            project.add("idProviders", idProviders);
        } else if (info.is(DbAppInfo)) {
            project.add("kind", "db");
        }

        JsonObjectBuilder injections = json.objectBuilder();
        for ((InjectionKey key, String value) : info.injections) {
            injections.add(key.name, value);
        }
        project.add("injections", injections);

        return project.build();
    }

    static JsonObject toJsonObject(SimpleResponse response) = [
        "status"  = response.status.code.toString(),
        "message" = response.toString()
    ];
}
