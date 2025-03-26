import json.*;

import web.*;
import web.responses.SimpleResponse;

import common.model.InjectionKey;
import common.model.ModuleInfo;
import common.model.RequiredModule;

/**
 * New API for module management.
 */
@WebService("/api/v1/modules")
@LoginRequired
@SessionRequired
service Modules
        extends CoreService {

    ModuleEndpoint delegate.get() {
        private @Lazy ModuleEndpoint delegate_.calc() = new ModuleEndpoint();

        ModuleEndpoint delegate = delegate_;
        delegate.request = this.request;
        return delegate;
    }

    @Get("/")
    JsonArray getModules() {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        Map<String, ModuleInfo> modules = accountInfo.modules;

        JsonArrayBuilder response = json.arrayBuilder();
        for (ModuleInfo info : modules.values) {
            response.addObject(toJsonObject(info));
        }
        return response.build();
    }

    @Get("{/id}")
    JsonObject|HttpStatus getModule(String id) {
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        if (ModuleInfo info := accountInfo.modules.get(id)) {
            return toJsonObject(info);
        } else {
            return NotFound;
        }
    }

    @Post("/")
    JsonArray|SimpleResponse upload() {
        JsonArrayBuilder response = json.arrayBuilder();

        // TODO: extract the common part between this and delegate.upload()

        return response.build();
    }

    // ----- helpers -------------------------------------------------------------------------------

    static JsonObject toJsonObject(ModuleInfo info) = [
        "id"           = info.name,
        "name"         = info.name,
        "version"      = "1.0",
        "date"         = info.uploaded.toString(),
        "kind"         = info.kind.toString(),
        "dependencies" = buildDependencies(info),
        "injections"   = buildInjections(info),
    ];

    static JsonArray buildDependencies(ModuleInfo info) {
        JsonArrayBuilder dependencies = json.arrayBuilder();
        for (RequiredModule dependencyInfo : info.dependencies) {
            dependencies.addObject([
                "name"    = dependencyInfo.name,
                "error"   = !dependencyInfo.available,
                "message" = dependencyInfo.available ? "" : "Missing dependency",
            ]);
        }
        return dependencies.build();
    }

    static JsonArray buildInjections(ModuleInfo info) {
        JsonArrayBuilder injections = json.arrayBuilder();
        for (InjectionKey key : info.injections) {
            injections.addObject([
                "name" = key.name,
                "type" = key.type,
            ]);
        }
        return injections.build();
    }
}
