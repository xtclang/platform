import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import ecstasy.reflect.ModuleTemplate;

import web.*;
import web.http.FormDataFile;

import common.model2.AccountInfo;
import common.model2.ModuleInfo;
import common.model2.WebAppInfo;
import common.model2.DependentModule;

import common.utils;

/**
 * Dedicated service for hosting modules
 */
@WebService("/hosting")
@LoginRequired
service Hosting() {

    construct() {
        accountManager = ControllerConfig.accountManager2;
        hostManager    = ControllerConfig.hostManager;
    }

    /**
     * The account manager.
     */
    private AccountManager2 accountManager;

    /**
     * The host manager.
     */
    private HostManager hostManager;

    /**
     * The current account name.
     */
    String accountName.get() {
        return session?.userId? : "";
    }

    /**
     * Returns a JSON map of all uploaded modules for given account.
     * Information comes from the AccountManager (the assumption is the Account manager maintains the
     * consistency between the DB and disk storage)
     */
    @Get("availableModules")
    Map<String, ModuleInfo> getAvailable() {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new ListMap();
        }
        return accountInfo.modules;
    }

    /**
     * Handles a request to upload module(s) and performs the following
     *  - saves the file(s) to disk (TODO delegate to the AccountManager)
     *  - builds ModuleInfo for each module
     *  - attempt to resolve module(s) if resolveParam == True
     *  - stores the ModuleInfo(s) in the Account
     *
     * TODO decide if the resolveParam should be a query parameter or in the body.
     *      currently it's unclear how to get a non-file entry from the body
     */
    @Post("upload")
    String[] uploadModule(@QueryParam("resolve") String resolveParam) {
        assert RequestIn request ?= this.request;

        String[] results = [];
        if (web.Body body ?= request.body) {
            Directory libDir = hostManager.ensureUserLibDirectory(accountName);

            @Inject Container.Linker linker;

            for (FormDataFile fileData : http.extractFileData(body)) {
                File file = libDir.fileFor(fileData.fileName);
                file.contents = fileData.contents;

                try {
                    ModuleTemplate template      = linker.loadFileTemplate(file).mainModule;
                    String         qualifiedName = template.qualifiedName + ".xtc";

                    // save the file
                    /* TODO move the file saving operation to the AccountManager manager
                            so it can maintain the consistency between the DB and disk */
                    if (qualifiedName != file.name) {
                        if (File fileOld := libDir.findFile(qualifiedName)) {
                            fileOld.delete();
                        }
                        if (file.renameTo(qualifiedName)) {
                            results += $"Stored module: {template.qualifiedName}";
                        } else {
                            results += $"Invalid or duplicate module name: {template.qualifiedName}";
                        }
                    }

                    Boolean resolve = utils.toBoolean(resolveParam);

                    accountManager.addOrUpdateModule(
                        accountName,
                        buildModuleInfo(libDir, template.qualifiedName, resolve)
                    );

                    updateDependant(libDir, template.qualifiedName, resolve);


                } catch (Exception e) {
                    file.delete();
                    results += $"Invalid module file: {e.message}";
                }
            }
        }
       return results;
    }

    /**
     * Handles a request to delete a module and performs the following
     *  - removes the ModuleInfo from the Account
     *  - deletes the file (TODO delegate to the AccountManager)
     *  - update ModuleInfos for each module that depends on the removed module
     */
    @Delete("module/{name}")
    HttpStatus deleteModule(String name) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return HttpStatus.Unauthorized;
        }
        if (WebAppInfo info := accountInfo.webApps.get(name)) {
            // TODO remove the app as well
            return HttpStatus.Conflict;
        } else {
            accountManager.removeModule(accountName, name);
            Directory libDir = hostManager.ensureUserLibDirectory(accountName);
            if (File|Directory f := libDir.find(name + ".xtc")) {
                if (f.is(File)) {
                    f.delete();
                    updateDependant(libDir, name, True);
                    return HttpStatus.OK;
                } else {
                    return HttpStatus.NotFound;
                }
            } else {
                return HttpStatus.NotFound;
            }
        }
    }

    /**
     * Handles a request to resolve a module
     */
    @Post("resolve/{name}")
    HttpStatus resolve(String name) {
        Directory libDir = hostManager.ensureUserLibDirectory(accountName);
        @Inject Container.Linker linker;

        try {
            accountManager.addOrUpdateModule(accountName, buildModuleInfo(libDir, name, True));
            return HttpStatus.OK;
        } catch (Exception e) {
            @Inject Console console;
            console.print(e);
            return HttpStatus.InternalServerError;
        }
    }


    /**
     * Iterates over modules that depend on `name` and rebuilds their ModuleInfos
     */
    private void updateDependant (Directory libDir, String name, Boolean resolve) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return ;
        }

        for (ModuleInfo moduleInfo : accountInfo.modules.values) {
            for (DependentModule dependent : moduleInfo.dependentModules) {
                if (dependent.qualifiedName == name) {
                    accountManager.addOrUpdateModule(
                        accountName,
                        buildModuleInfo(libDir, moduleInfo.name, resolve)
                    );
                    break;
                }
            }
        }
    }

    /**
     * Generates ModuleInfo for `name` module.
     * If `resolve == True` also attempts to resolve the module.
     */
    private ModuleInfo buildModuleInfo (Directory libDir, String moduleName, Boolean resolve) {
        String[] issues=[];
        Boolean isResolved = False;
        Boolean isWebModule = False;
        DependentModule[] dependentModules = [];

        // get dependent modules
        @Inject("repository") ModuleRepository coreRepo;
        ModuleRepository accountRepo =
            new LinkedRepository([coreRepo, new DirRepository(libDir)].freeze(True));

        if (ModuleTemplate mod := accountRepo.getModule(moduleName)) {
            for ((String depName, String depQualifiedName) : mod.moduleNamesByPath) {
                dependentModules +=
                    new DependentModule(depName, depQualifiedName, accountRepo.getModule(depQualifiedName));
            }
        }

        // resolve the module
        if (resolve) {
            try {
                ModuleTemplate mod = accountRepo.getResolvedModule(moduleName);
                isResolved = True;
                isWebModule = mod.findAnnotation("web.WebApp");
            } catch (Exception e) {
                issues += e.text?;
            }
        }

        return new ModuleInfo(
            moduleName,
            moduleName,
            isResolved,
            isWebModule,
            issues,
            dependentModules
        );
    }


}