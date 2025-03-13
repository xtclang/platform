import json.*;
import web.*;
import web.responses.SimpleResponse;

import common.model.AppInfo;
import common.model.InjectionKey;
import common.model.WebAppInfo;

/**
 * New API for project (deployment) management.
 */
@WebService("/api/v1/projects")
@LoginRequired
@SessionRequired
service Projects {

    AppEndpoint delegate.get() {
        private @Lazy AppEndpoint delegate_.calc() = new AppEndpoint();

        AppEndpoint delegate = delegate_;
        delegate.request = this.request;
        return delegate;
    }

    @Get("/")
    JsonArray getProjects() {
        Map<String, AppInfo> deployments = delegate.checkStatus();

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
    JsonObject|SimpleResponse getProject(String id) {
        AppInfo|SimpleResponse info = delegate.checkStatus(id);
        return info.is(SimpleResponse) ? info : toJsonObject(info);
    }

    static JsonObject toJsonObject(AppInfo info) = [
        "id"        = info.deployment,
        "name"      = info.deployment,
        "module"    = info.moduleName,
        "autoStart" = info.autoStart,
    ];
}
