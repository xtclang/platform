import json.*;
import web.*;
import web.responses.SimpleResponse;

import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.ModuleInfo;
import common.model.InjectionKey;
import common.model.Injections;
import common.model.WebAppInfo;

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
    @Options("{/path}")
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

        String     deployment = projectInfo["name"].as(String);
        String     moduleName = projectInfo["module"].as(String);
        String?    provider   = projectInfo["certProvider"].as(String?);
        JsonArray? injections = projectInfo["injections"].as(JsonArray?);

        (Injections | SimpleResponse) result = delegate.prepareRegister(deployment, moduleName);
        if (result.is(SimpleResponse)) {
            return toJsonObject(result);
        }
        assert ModuleInfo moduleInfo := accountInfo.modules.get(moduleName);

        AppInfo|SimpleResponse appInfo;
        if (moduleInfo.kind == Web) {
            if (provider == Null || provider.empty) {
                provider = "self";
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

        AppInfo|SimpleResponse appInfo = delegate.getAppInfo(id);
        if (appInfo.is(SimpleResponse)) {
            return toJsonObject(appInfo);
        }

        String?    provider   = projectInfo["certProvider"].as(String?);
        JsonArray? injections = projectInfo["injections"].as(JsonArray?);

        if (injections != Null && !injections.empty) {
            for (Doc pair : injections) {
                assert pair.is(JsonObject) && pair.size == 1;
                for ((Doc key, Doc value) : pair) {
                    SimpleResponse response = delegate.setInjectionValue(
                        id, key.as(String), value.as(String));
                    if (response.status != OK) {
                        return toJsonObject(response);
                    }
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

    static JsonObject toJsonObject(AppInfo info) {
        JsonObjectBuilder project = json.objectBuilder();
        project.addAll([
            "id"        = info.deployment,
            "name"      = info.deployment,
            "module"    = info.moduleName,
            "autoStart" = info.autoStart,
            "active"    = info.active,
        ]);

        if (info.is(WebAppInfo)) {
            project.addAll([
                "type"         = "web",
                "domain"       = info.hostName,
                "sharedDbs"    = info.sharedDBs,
                "certProvider" = info.provider,
                "useCookies"   = info.useCookies,
                "useAuth"      = info.useAuth,
            ]);
        } else if (info.is(DbAppInfo)) {
            project.add("type", "db");
        }

        JsonArrayBuilder injections = json.arrayBuilder();
        for ((InjectionKey key, String value) : info.injections) {
            injections.addObject([key.name=value]);
        }
        project.add("injections", injections);

        return project.build();
    }

    static JsonObject toJsonObject(SimpleResponse response) = [
        "status"  = response.status.code.toString(),
        "message" = response.toString()
    ];
}
