import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;
import ecstasy.reflect.TypeTemplate;

import web.*;
import web.http.FormDataFile;
import web.responses.SimpleResponse;

import common.AppHost;
import common.DbHost;
import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.DbAppInfo;
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
@SessionRequired
service ModuleEndpoint
        extends CoreService {

    /**
     * Return a JSON map of all uploaded modules for given account.
     *
     * Information comes from the AccountManager (the assumption is the Account manager maintains
     * the consistency between the DB and disk storage).
     */
    @Get("all")
    Map<String, ModuleInfo> getAvailable() {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            return accountInfo.modules;
        }
        return [];
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
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        String[] messages = [];
        if (web.Body body ?= request.body) {
            Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
            ModuleRepository accountRepo = utils.getModuleRepository(libDir);

            @Inject Container.Linker linker;

            Set<String> affectedModules = new HashSet();
            for (FormDataFile fileData : http.extractFileData(body)) {
                File file = libDir.fileFor(fileData.fileName);
                file.contents = fileData.contents;

                try {
                    ModuleTemplate template   = linker.loadFileTemplate(file).mainModule;
                    String         moduleName = template.qualifiedName;
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
                            messages += $|Invalid or duplicate module name: "{moduleName}"
                                         ;
                        }
                    }

                    ModuleInfo info = buildModuleInfo(accountRepo, moduleName);

                    accountManager.addOrUpdateModule(accountName, info);

                    affectedModules += moduleName;
                    affectedModules += updateDependencies(accountRepo, moduleName);
                } catch (Exception e) {
                    file.delete();
                    messages += $"Invalid module file {fileData.fileName.quoted()}: {e.message}";
                }
            }

            if (allowRedeployment && affectedModules.size > 0) {
                String[] deployments = new String[];
                for ((String deployment, AppInfo appInfo) : accountInfo.apps) {
                    if (AppHost host := hostManager.getHost(deployment),
                            affectedModules.contains(host.moduleName)) {
                    deployments += deployment;
                    }
                }
                messages += $|Redeploying {deployments.toString(sep=", ", pre="", post="")}
                            ;
                redeploy^(accountRepo, deployments);
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
    @Delete("/delete{/moduleName}")
    SimpleResponse deleteModule(String moduleName) {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName),
            accountInfo.modules.contains(moduleName)) {

            Set<String> dependentDeployments = accountInfo.collectDeployments(moduleName);
            if (!dependentDeployments.empty) {
                return new SimpleResponse(Conflict,
                        bytes=dependentDeployments.toString(sep=",", pre="", post="").utf8());
            }

            accountManager.removeModule(accountName, moduleName);

            Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
            ModuleRepository accountRepo = utils.getModuleRepository(libDir);
            if (File|Directory f := libDir.find(moduleName + ".xtc")) {
                if (f.is(File)) {
                    f.delete();
                    // there could be un-deployed modules that depend on this one;
                    // mark them as "unresolved"
                    updateDependencies(accountRepo, moduleName);
                }
            return new SimpleResponse(OK);
            }
        }
        return new SimpleResponse(NotFound);
    }

    /**
     * Handles a request to resolve a module
     */
    @Post("/resolve{/moduleName}")
    SimpleResponse resolve(String moduleName) {
        ModuleRepository accountRepo = utils.getModuleRepository(
                hostManager.ensureAccountLibDirectory(accountName));
        try {
            accountManager.addOrUpdateModule(accountName, buildModuleInfo(accountRepo, moduleName));
            return new SimpleResponse(OK);
        } catch (Exception e) {
            return new SimpleResponse(InternalServerError, e.message);
        }
    }

    /**
     * Iterate over modules that depend on the specified `moduleName` and rebuild their ModuleInfos.
     *
     * @return an array of affected module names
     */
    private String[] updateDependencies(ModuleRepository accountRepo, String moduleName) {
        String[] affectedNames = [];
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            for (ModuleInfo moduleInfo : accountInfo.modules.values) {
                if (moduleInfo.dependsOn(moduleName)) {
                    String     affectedName = moduleInfo.name;
                    ModuleInfo newInfo      = buildModuleInfo(accountRepo, affectedName);

                    accountManager.addOrUpdateModule(accountName, newInfo);

                    if (newInfo.isResolved) {
                        affectedNames += affectedName;
                    }
                }
            }
        }
        return affectedNames;
    }

    /**
     * Generate ModuleInfo for the specified module.
     */
    private ModuleInfo buildModuleInfo(ModuleRepository accountRepo, String moduleName) {
         // collect the dependencies (the module names the specified module depends on)
        RequiredModule[] dependencies = [];
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
        Boolean    isResolved = False;
        ModuleType moduleType = Generic;
        String[]   issues     = [];
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
     * Redeploy all specified deployments.
     *
     * Note: this method executes asynchronously.
     */
    private void redeploy(ModuleRepository accountRepo, String[] deployments) {
        ErrorLog errors = new ErrorLog();

        for (String deployment : deployments) {
            if (AppHost host := hostManager.getHost(deployment), AppInfo appInfo ?= host.appInfo) {

                import common.model.InjectionKey;
                import common.model.Injections;

                // adjust the injections map if necessary
                AppInfo?       newInfo = Null;
                InjectionKey[] injectionKeys;
                if (injectionKeys :=
                        utils.collectDestringableInjections(accountRepo, host.moduleName)) {

                    Injections injections = appInfo.injections;
                    if (injectionKeys.as(Collection) != injections.keys.as(Collection)) {
                        Injections newInjections = new ListMap();
                        for (InjectionKey key : injectionKeys) {
                            injections.put(key, injections.getOrDefault(key, ""));
                        }
                        newInfo = appInfo.with(injections=newInjections);
                    }
                }

                // redeploy if necessary and possible
                if (host.active) {
                    // TODO: schedule a redeployment for later
                    host.log($|Warning: The application "{deployment}" is active and needs to \
                              |be redeployed manually"
                            );
                } else if (appInfo.autoStart) {
                    hostManager.removeHost(host);

                    if (appInfo.is(WebAppInfo)) {
                        if (!hostManager.createWebHost(accountName, appInfo,
                                accountManager.decrypt(appInfo.password), errors)) {
                            host.log($|Error: Failed to redeploy "{deployment}"; \
                                      |reason: {errors}"
                                      |
                                      );
                            newInfo = appInfo.with(autoStart=False);
                        }
                    } else if (appInfo.is(DbAppInfo)) {
                        if (!(host := hostManager.createDbHost(accountName, appInfo, errors))) {
                            host.log($|Error: Failed to redeploy "{deployment}"; \
                                  |reason: {errors}"
                                  |
                                  );
                            newInfo = appInfo.with(autoStart=False);
                        }
                    }
                    errors.reset();

                    if (newInfo != Null) {
                        accountManager.addOrUpdateApp(accountName, newInfo);
                    }
                }
            }
        }
    }
}