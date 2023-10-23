import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.WebAppInfo;
import common.model.RequiredModule;

import web.*;
import web.responses.SimpleResponse;

/**
 * Dedicated service for operations on WebApps.
 */
@WebService("/webapp")
@LoginRequired
service WebAppEndpoint() {

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
     * Return a JSON map of all webapps for given account.
     */
    @Get("all")
    Map<String, WebAppInfo> getAvailable() {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            return accountInfo.webApps;
        }
        return new ListMap();
    }

    /**
     * Handle a request to register a webapp for a module.
     * Assumptions:
     *  - many webapps can be registered from the same module with different deployment
     *  - a deployment has one and only one webapp
     */
    @Post("/register/{deployment}/{moduleName}")
    HttpStatus register(String deployment, String moduleName) {

        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return HttpStatus.Unauthorized;
        }

        if (accountInfo.webApps.contains(deployment)) {
            return HttpStatus.Conflict;
        }

        if (!accountInfo.modules.contains(moduleName)) {
            return HttpStatus.NotFound;
        }

        (String hostName, String bindAddr, UInt16 httpPort, UInt16 httpsPort) = getAuthority(deployment);
        accountManager.addOrUpdateWebApp(accountName,
            new WebAppInfo(deployment, moduleName, hostName, bindAddr, httpPort, httpsPort, False));
        return HttpStatus.OK;
    }

    /**
     * Handle a request to unregister a deployment.
     */
    @Delete("/unregister/{deployment}")
    SimpleResponse unregister(String deployment) {
        SimpleResponse response = stopWebApp(deployment);
        if (response.status == OK) {
            accountManager.removeWebApp(accountName, deployment);
        }

        return response;
    }

    /**
     * Handle a request to start a deployment.
     */
    @Post("/start/{deployment}")
    SimpleResponse startWebApp(String deployment) {
        HttpStatus  status  = OK;
        String?     message = Null;
        do {
            AccountInfo accountInfo;
            if (!(accountInfo := accountManager.getAccount(accountName))) {
                (status, message) = (NotFound, $"Account '{accountName}' is missing");
                break;
            }

            WebAppInfo webAppInfo;
            if (!(webAppInfo := accountInfo.webApps.get(deployment))) {
                (status, message) = (NotFound, $"Invalid deployment '{deployment}'");
                break;
            }

            if (hostManager.getWebHost(deployment)) {
                if (!webAppInfo.active) {
                    // the host is marked as inactive; fix it
                    accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(True));
                    }
                (status, message) = (OK, $"The application is already running");
                break;
                }

            ErrorLog errors = new ErrorLog();
            if (!hostManager.createWebHost(accountName, webAppInfo, errors)) {
                (status, message) = (Conflict, errors.collectErrors());
                break;
            }

            accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(True));
        } while (False);

        return new SimpleResponse(status, bytes=message?.utf8() : Null);
    }

//    /**
//     * Show the console's content (currently unused).
//     */
//    @Get("report/{deployment}")
//    @Produces(Text)
//    String report(String deployment) {
//        if (WebHost webHost := hostManager.getWebHost(deployment)) {
//            File consoleFile = webHost.homeDir.fileFor("console.log");
//            if (consoleFile.exists && consoleFile.size > 0) {
//                return consoleFile.contents.unpackUtf8();
//            }
//        }
//        return "[empty]";
//    }
//
    /**
     * Handle a request to stop a deployment.
     */
    @Post("/stop/{deployment}")
    SimpleResponse stopWebApp(String deployment) {
        HttpStatus  status  = OK;
        String?     message = Null;
        do {
            AccountInfo accountInfo;
            if (!(accountInfo := accountManager.getAccount(accountName))) {
                (status, message) = (NotFound, $"Account '{accountName}' is missing");
                break;
            }

            WebAppInfo webAppInfo;
            if (!(webAppInfo := accountInfo.webApps.get(deployment))) {
                (status, message) = (NotFound, $"Invalid deployment '{deployment}'");
                break;
            }

            WebHost webHost;
            if (!(webHost := hostManager.getWebHost(deployment))) {
                if (webAppInfo.active) {
                    // there's no host, but the deployment is marked as active; fix it
                    accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(False));
                    }
                (status, message) = (OK, "The application is not running");
                break;
            }

            hostManager.removeWebHost(webHost);
            accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(False));
        } while (False);

        return new SimpleResponse(status, bytes=message?.utf8() : Null);
    }


    // ----- helpers -------------------------------------------------------------------------------

    /**
     * Get the host name and ports for the specified deployment.
     */
    (String hostName, String bindAddr, UInt16 httpPort, UInt16 httpsPort) getAuthority(String deployment) {
        assert UInt16 httpPort := accountManager.allocatePort(ControllerConfig.userPorts);

        return ControllerConfig.hostName, ControllerConfig.bindAddr, httpPort, httpPort+1;
    }


}