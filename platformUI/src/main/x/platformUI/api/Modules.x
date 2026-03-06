import ecstasy.mgmt.ModuleRepository;

import json.*;

import web.*;
import web.responses.SimpleResponse;

import common.model.InjectionKey;
import common.model.ModuleInfo;
import common.model.RequiredModule;

import common.utils;

import ModuleEndpoint.UploadInfo;

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

    // TODO: very temporary; remove
    @Options("{/path*}")
    @SessionOptional
    @LoginOptional
    HttpStatus preflight() = OK;

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
    JsonArray upload() {
        Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
        ModuleRepository accountRepo = utils.getModuleRepository(libDir);

        UploadInfo[] uploads = delegate.extractModule(libDir, accountRepo);

        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        JsonArrayBuilder response = json.arrayBuilder();
        for (UploadInfo upload : uploads) {
            if (String failure ?= upload.failure) {
                response.addObject([
                    "error"    = True,
                    "fileName" = upload.fileName,
                    "message"  = failure,
                ]);
            } else {
                // we don't keep the file name; just supply it in the response for the correlation
                assert String     moduleName ?= upload.moduleName,
                       ModuleInfo moduleInfo := accountInfo.modules.get(moduleName);
                response.addObject(toJsonObject(moduleInfo, upload.fileName));
            }
        }

        return response.build();
    }

    @Delete("{/id}")
    JsonObject|SimpleResponse deleteModule(String id) {
        SimpleResponse response = delegate.deleteModule(id);
        if (response.status == Conflict) {
            String message = response.bytes.unpackUtf8();
            return ["errors"=message];
        } else {
            return response;
        }
    }

    // ----- helpers -------------------------------------------------------------------------------

    static JsonObject toJsonObject(ModuleInfo info, String fileName = "") = [
        "id"           = info.name,
        "name"         = info.name,
        "fileName"     = fileName,
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
