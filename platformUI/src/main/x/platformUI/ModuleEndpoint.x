import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import ecstasy.reflect.ModuleTemplate;
import ecstasy.reflect.TypeTemplate;

import web.*;
import web.http.FormDataFile;

import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.ModuleType;
import common.model.WebAppInfo;
import common.model.RequiredModule;

import common.utils;

/**
 * Dedicated service for hosting modules.
 */
@WebService("/module")
@LoginRequired
service ModuleEndpoint() {

    construct() {
        accountManager = ControllerConfig.accountManager;
        hostManager    = ControllerConfig.hostManager;
    }

    /**
     * The account manager.
     */
    private AccountManager accountManager;

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
     * Return a JSON map of all uploaded modules for given account.
     *
     * Information comes from the AccountManager (the assumption is the Account manager maintains
     * the consistency between the DB and disk storage).
     */
    @Get("all")
    Map<String, ModuleInfo> getAvailable() {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new ListMap();
        }
        return accountInfo.modules;
    }

    /**
     * Handle a request to upload module(s) and perform the following:
     *  - save the file(s) to disk (TODO delegate to the AccountManager)
     *  - build ModuleInfo for each module
     *  - resolve module(s)
     *  - store the ModuleInfo(s) in the Account
     *  - re-deploy all the affected active deployments if allowed
     *
     * @return a list of successfully uploaded module names
     */
    @Post("upload")
    String[] uploadModule(@QueryParam("redeploy") Boolean allowRedeployment) {
        assert RequestIn request ?= this.request;

        String[] messages = [];
        if (web.Body body ?= request.body) {
            Directory libDir = hostManager.ensureUserLibDirectory(accountName);

            @Inject Container.Linker linker;

            Set<String> affectedWebModules = new HashSet();
            for (FormDataFile fileData : http.extractFileData(body)) {
                File file = libDir.fileFor(fileData.fileName);
                file.contents = fileData.contents;

                try {
                    ModuleTemplate template   = linker.loadFileTemplate(file).mainModule;
                    String         moduleName =  template.qualifiedName;
                    String         fileName   =  moduleName + ".xtc";

                    // save the file
                    /* TODO move the file saving operation to the AccountManager manager
                            so it can maintain the consistency between the DB and disk */
                    if (fileName != file.name) {
                        if (File fileOld := libDir.findFile(fileName)) {
                            fileOld.delete();
                        }
                        if (file.renameTo(fileName)) {
                            messages += $|Stored "{fileData.fileName}" module as: "{moduleName}"
                                       ;
                        } else {
                            messages += $|Invalid or duplicate module name: {moduleName}"
                                       ;
                        }
                    }

                    ModuleInfo info = buildModuleInfo(libDir, moduleName);

                    accountManager.addOrUpdateModule(accountName, info);

                    if (info.moduleType == Web) {
                        affectedWebModules += moduleName;
                    }
                    affectedWebModules += updateDependencies(libDir, moduleName);
                } catch (Exception e) {
                    file.delete();
                    messages += $"Invalid module file {fileData.fileName.quoted()}: {e.message}";
                }
            }

            if (allowRedeployment && affectedWebModules.size > 0) {
                messages += $|Redeploying {affectedWebModules.toString(sep=",", pre="", post="")}
                            ;
                redeploy(affectedWebModules);
            }
        }
       return messages;
    }

    /**
     * Handle a request to delete a module and perform the following:
     *  - remove the ModuleInfo from the Account
     *  - delete the file (TODO delegate to the AccountManager)
     *  - update ModuleInfos for each module that depends on the removed module
     *
     * @return `OK` if operation succeeded; `Conflict` if there are any active applications that
     *         depend on the module; `NotFound` if the module is missing
     */
    @Delete("/delete/{name}")
    HttpStatus deleteModule(String name) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return HttpStatus.Unauthorized;
        }
        if (WebAppInfo info := accountInfo.webApps.get(name)) {
            return HttpStatus.Conflict;
        } else {
            accountManager.removeModule(accountName, name);
            Directory libDir = hostManager.ensureUserLibDirectory(accountName);
            if (File|Directory f := libDir.find(name + ".xtc")) {
                if (f.is(File)) {
                    f.delete();
                    updateDependencies(libDir, name);
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
    @Post("/resolve/{name}")
    HttpStatus resolve(String name) {
        Directory libDir = hostManager.ensureUserLibDirectory(accountName);
        try {
            accountManager.addOrUpdateModule(accountName, buildModuleInfo(libDir, name));
            return HttpStatus.OK;
        } catch (Exception e) {
            @Inject Console console;
            console.print(e);
            return HttpStatus.InternalServerError;
        }
    }

    /**
     * Iterate over modules that depend on the specified `moduleName` and rebuild their ModuleInfos.
     *
     * @return an array of affected WebModule names
     */
    private String[] updateDependencies(Directory libDir, String moduleName) {
        String[] affectedNames = [];
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            for (ModuleInfo moduleInfo : accountInfo.modules.values) {
                for (RequiredModule dependent : moduleInfo.dependencies) {
                    if (dependent.name == moduleName) {
                        String     affectedName = moduleInfo.name;
                        ModuleInfo newInfo      = buildModuleInfo(libDir, affectedName);

                        accountManager.addOrUpdateModule(accountName, newInfo);

                        if (moduleInfo.moduleType == Web && newInfo.isResolved) {
                            affectedNames += affectedName;
                        }
                        break;
                    }
                }
            }
        }
        return affectedNames;
    }

    /**
     * Generate ModuleInfo for the specified module.
     */
    private ModuleInfo buildModuleInfo(Directory libDir, String moduleName) {
        RequiredModule[] dependencies = [];

        // collect the dependencies (the module names the specified module depends on)
        @Inject("repository") ModuleRepository coreRepo;
        ModuleRepository accountRepo =
            new LinkedRepository([coreRepo, new DirRepository(libDir)].freeze(True));

        if (ModuleTemplate moduleTemplate := accountRepo.getModule(moduleName)) {
            for ((_, String requiredName) : moduleTemplate.moduleNamesByPath) {
                // everything depends on Ecstasy module; don't show it
                if (requiredName != TypeSystem.MackKernel &&
                        dependencies.all(m -> m.name != requiredName)) {
                    dependencies +=
                        new RequiredModule(requiredName, accountRepo.getModule(requiredName));
                }
            }
        }

        // resolve the module
        Boolean    isResolved  = False;
        ModuleType moduleType  = Generic;
        String[]   issues      = [];
        try {
            ModuleTemplate template = accountRepo.getResolvedModule(moduleName);
            isResolved  = True;

            if (utils.isWebModule(template)) {
                moduleType = Web;
            } else if (utils.isDbModule(template)) {
                moduleType = Db;
            }
        } catch (Exception e) {
            issues += e.text?;
        }

        return new ModuleInfo(moduleName, isResolved, moduleType, issues, dependencies);
    }

    /**
     * Redeploy all deployments that are based on the web module names in the specified set.
     *
     * TODO GG: make this async
     */
    private void redeploy(Set<String> moduleNames) {
        @Inject Console console;
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {

            ErrorLog errors = new ErrorLog();
            for ((String deployment, WebAppInfo info) : accountInfo.webApps) {
                if (WebHost webHost := hostManager.getWebHost(deployment),
                    moduleNames.contains(webHost.moduleName)) {

                    hostManager.removeWebHost(webHost);
                    if (!hostManager.createWebHost(accountName, info, errors)) {
                        console.print($"Failed to redeploy {deployment.quoted()}; reason: {errors}");
                        accountManager.addOrUpdateWebApp(accountName, info.updateStatus(False));
                    }
                    errors.reset();
                }
            }
        }
    }
}