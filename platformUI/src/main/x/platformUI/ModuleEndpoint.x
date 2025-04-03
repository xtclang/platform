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
import common.model.InjectionKey;
import common.model.ModuleInfo;
import common.model.ModuleKind;
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
        Directory        libDir      = hostManager.ensureAccountLibDirectory(accountName);
        ModuleRepository accountRepo = utils.getModuleRepository(libDir);

        UploadInfo[] uploads = extractModule(libDir, accountRepo);

        String[]    messages        = [];
        Set<String> affectedModules = new HashSet();
        for (UploadInfo upload : uploads) {

            if (String failure ?= upload.failure) {
                messages += failure;
                continue;
            }
            assert String moduleName ?= upload.moduleName;
            affectedModules += moduleName;
            affectedModules += updateDependencies(accountRepo, moduleName);
            messages        += $|Stored "{upload.fileName}" module as: "{moduleName}"
                                ;

            if (allowRedeployment && affectedModules.size > 0) {
                assert AccountInfo accountInfo := accountManager.getAccount(accountName);

                String[] deployments = new String[];
                for ((String deployment, AppInfo appInfo) : accountInfo.apps) {
                    if (AppHost host := hostManager.getHost(deployment),
                            affectedModules.contains(host.moduleName)) {
                    deployments += deployment;
                    }
                }
                if (!deployments.empty) {
                    messages += $|Redeploying {deployments.toString(sep=", ", pre="", post="")}
                                ;
                    redeploy^(accountRepo, deployments);
                }
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
            if (File file := libDir.findFile(moduleName + ".xtc")) {
                file.delete();
                // there could be un-deployed modules that depend on this one;
                // mark them as "unresolved"
                updateDependencies(accountRepo, moduleName);
            }

            return new SimpleResponse(OK);
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

            assert AccountInfo accountInfo := accountManager.getAccount(accountName);
            if (ModuleInfo moduleInfo := accountInfo.modules.get(moduleName)) {
                accountManager.addOrUpdateModule(accountName,
                    buildModuleInfo(accountRepo, moduleName, moduleInfo.uploaded));
                return new SimpleResponse(OK);
            } else {
                return new SimpleResponse(NotFound);
            }
        } catch (Exception e) {
            return new SimpleResponse(Conflict, e.message);
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
                if (!moduleInfo.dependsOn(moduleName)) {
                    continue;
                }

                String     affectedName = moduleInfo.name;
                ModuleInfo newInfo      = buildModuleInfo(accountRepo, affectedName, moduleInfo.uploaded);

                accountManager.addOrUpdateModule(accountName, newInfo);

                if (newInfo.resolved) {
                    affectedNames += affectedName;
                }
            }
        }
        return affectedNames;
    }

    // ----- helpers -------------------------------------------------------------------------------

    const UploadInfo(String  fileName,          // the name of the uploaded file (used for UI only)
                     String? moduleName = Null, // the module name; Null if the file is corrupted
                     String? failure    = Null, // not Null if any failures occurred
                    );
    /**
     * Extract and save the uploaded module to the repository. Save a previous version (if exists)
     * with a "_bak" extension for processing by the DB migration logic.
     */
    UploadInfo[] extractModule(Directory libDir, ModuleRepository accountRepo) {
        @Inject Clock clock;

        assert RequestIn request ?= this.request;
        assert AccountInfo accountInfo := accountManager.getAccount(accountName);

        UploadInfo[] uploads = [];

        if (web.Body body ?= request.body) {
            @Inject Container.Linker linker;

            for (FormDataFile fileData : http.extractFileData(body)) {
                String fileName = fileData.fileName;
                File   fileTemp = utils.createTempFile(libDir);

                fileTemp.contents = fileData.contents;

                ModuleTemplate template;
                try {
                    template = linker.loadFileTemplate(fileTemp).mainModule;
                } catch (Exception e) {
                    fileTemp.delete();
                    uploads += new UploadInfo(fileName,
                            failure=$"Invalid module file {fileName.quoted()}: {e.message}");
                    continue;
                }

                String moduleName = template.qualifiedName;
                String storeName = $"{moduleName}.xtc";

                // TODO: this is very temporary; we should keep old the versions until they are
                //       no longer used and provide a way to evolve DBs
                if (File fileOld := libDir.findFile(storeName)) {
                    fileOld.delete();
                }
                assert fileTemp.renameTo(storeName);

                accountManager.addOrUpdateModule(accountName,
                        buildModuleInfo(accountRepo, moduleName, clock.now));
                uploads += new UploadInfo(fileName, moduleName);
            }
        }
        return uploads.freeze(inPlace=True);
    }

    /**
     * Generate ModuleInfo for the specified module.
     */
    private ModuleInfo buildModuleInfo(ModuleRepository accountRepo, String moduleName,
                                       Time uploaded) {
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
        Boolean        resolved      = False;
        ModuleKind     kind          = Generic;
        String[]       issues        = [];
        InjectionKey[] injectionKeys = [];
        try {
            ModuleTemplate template = accountRepo.getResolvedModule(moduleName);
            resolved = True;

            assert injectionKeys := utils.collectDestringableInjections(accountRepo, moduleName);

            if (utils.isWebModule(template)) {
                kind = Web;
            } else if (utils.isDbModule(template)) {
                kind = Db;
            }
        } catch (Exception e) {
            issues += e.text?;
        }

        return new ModuleInfo(moduleName, resolved, uploaded, kind, issues, dependencies,
                              injectionKeys);
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