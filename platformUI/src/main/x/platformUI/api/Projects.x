import json.*;
import web.*;
import web.responses.SimpleResponse;

import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.ModuleInfo;
import common.model.InjectionKey;
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

    @Get("/")
    JsonArray getProjects() {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        Map<String, AppInfo> deployments = accountInfo.apps;

        JsonArrayBuilder response = json.arrayBuilder();
        for (AppInfo info : deployments.values) {
            JsonObjectBuilder project = json.objectBuilder();
            project.addAll(toJsonObject(info));

            JsonArrayBuilder injections = json.arrayBuilder();
            for ((InjectionKey key, String value) : info.injections) {
                injections.addObject([key.name=value]);
            }

            project.add("injections", injections);

            if (info.is(WebAppInfo)) {
                project.add("sharedDbs", info.sharedDBs);
            }

            response.add(project);
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

    static JsonObject toJsonObject(AppInfo info) = [
        "id"        = info.deployment,
        "name"      = info.deployment,
        "module"    = info.moduleName,
        "autoStart" = info.autoStart,
    ];
}
