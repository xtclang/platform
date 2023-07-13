import ecstasy.mgmt.Container;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.WebModuleInfo;

import web.*;
import web.http.FormDataFile;

@WebService("/host")
@LoginRequired
service Controller() {

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

    @Get("userId")
    String getUserId() {
        return accountName;
    }

    @Get("registeredApps")
    ModuleInfo[] getRegistered() {
        if (AccountInfo info := accountManager.getAccount(accountName)) {
            return info.modules.values.toArray();
        }
        return [];
    }

    @Get("availableModules")
    String[] getAvailable() {
        Directory libDir = hostManager.ensureUserLibDirectory(accountName);
        return libDir.names()
                   .filter(name -> name.endsWith(".xtc"))
                   .map(name -> name[0 ..< name.size-4])
                   .toArray(Constant);
    }

    @Post("upload")
    String[] uploadModule() {
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
                    if (qualifiedName != file.name) {
                        if (file.renameTo(qualifiedName)) {
                            results += $"Stored module: {template.qualifiedName}";
                        } else {
                            file.delete();
                            results += $"Invalid or duplicate module name: {template.qualifiedName}";
                        }
                    }
                } catch (Exception e) {
                    file.delete();
                    results += $"Invalid module file: {e.message}";
                }
            }
        }
       return results;
    }

    @Post("load")
    json.Doc load(@QueryParam("app") String appName, @QueryParam String domain) {
        // there is one and only one application per [sub] domain
        WebHost webHost;
        if (webHost := hostManager.getWebHost(domain)) {}
        else {
            AccountInfo accountInfo;
            if (!(accountInfo := accountManager.getAccount(accountName))) {
                return [False, $"account {accountName} is missing"];
            }

            WebModuleInfo webInfo;
            Boolean       newApp;
            if (ModuleInfo info := accountInfo.modules.get(appName)) {
                assert webInfo := info.is(WebModuleInfo);
                newApp = False;
            } else {
                (String hostName, String bindAddr, UInt16 httpPort, UInt16 httpsPort) = getAuthority(domain);

                webInfo = new WebModuleInfo(appName, domain, hostName, bindAddr, httpPort, httpsPort);
                newApp  = True;
            }

            ErrorLog errors = new ErrorLog();
            if (!(webHost := hostManager.ensureWebHost(accountName, webInfo, errors))) {
                return [False, errors.toString()];
            }

            if (newApp) {
                accountManager.addModule(accountName, webInfo);
            }
        }
        return [True, $"http://{webHost.info.hostName}:{webHost.info.httpPort}"];
    }

    @Get("report/{domain}")
    String report(String domain) {
        String response;
        if (WebHost webHost := hostManager.getWebHost(domain)) {
            Container container = webHost.container;
            response = $"{container.status} {container.statusIndicator}";
        } else {
            response = "Not loaded";
        }
        return response;
    }

    @Post("unload/{domain}")
    HttpStatus unload(String domain) {
        if (WebHost webHost := hostManager.getWebHost(domain)) {
            hostManager.removeWebHost(webHost);
            webHost.close();

            return HttpStatus.OK;
        }
        return HttpStatus.NotFound;
    }

    @Post("unregister")
    HttpStatus unregister(@QueryParam("app") String appName, @QueryParam String domain) {
        unload(domain);

        accountManager.removeModule(accountName, appName);
        return HttpStatus.OK;
    }

    @Put("sign-out")
    HttpStatus signOut() {
        session?.deauthenticate();
        return HttpStatus.OK;
    }

    @Post("debug")
    @LoginOptional // TODO: remove
    HttpStatus debug() {
        assert:debug;
        return HttpStatus.OK;
    }

    @Post("shutdown")
    @LoginOptional // TODO: TEMPORARY: only the admin can shutdown the host
    HttpStatus shutdown() {
        try {
            hostManager.shutdown();
            accountManager.shutdown();
        } finally {
            callLater(ControllerConfig.shutdownServer);
        }
        return HttpStatus.OK;
    }


    // ----- helpers -------------------------------------------------------------------------------

    /**
     * Get the host name and ports for the specified domain.
     */
    (String hostName, String bindAddr, UInt16 httpPort, UInt16 httpsPort) getAuthority(String domain) {
        assert UInt16 httpPort := accountManager.allocatePort(ControllerConfig.userPorts);

        return ControllerConfig.hostName, ControllerConfig.bindAddr, httpPort, httpPort+1;
    }
}