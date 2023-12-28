import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.WebAppInfo;

import web.*;
import web.responses.SimpleResponse;

/**
 * Dedicated service for operations on WebApps.
 */
@WebService("/webapp")
@LoginRequired
service WebAppEndpoint
        extends CoreService {

    /**
     * Return a JSON map of all webapps for given account.
     */
    @Get("all")
    Map<String, WebAppInfo> getAvailable() {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            return accountInfo.webApps;
        }
        return [];
    }

    /**
     * Return a JSON map of statuses for all webapps for given account.
     */
    @Get("status")
    Map<String, WebAppInfo> checkStatus() {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            HashMap<String, WebAppInfo> status = new HashMap();
            for ((String deployment, WebAppInfo info) : accountInfo.webApps) {
                if (WebHost webHost := hostManager.getWebHost(deployment)) {
                    info = info.updateStatus(webHost.active);
                }
                status.put(deployment, info);
            }
            return status.freeze(inPlace=True);
        }
        return [];
    }

    /**
     * Handle a request to register a webapp for a module.
     * Assumptions:
     *  - many webapps can be registered from the same module with a different deployment
     *  - a deployment has one and only one webapp
     */
    @Post("/register/{deployment}/{moduleName}")
    SimpleResponse register(String deployment, String moduleName) {
        HttpStatus  status  = OK;
        String?     message = Null;
        do {
            AccountInfo accountInfo;
            if (!(accountInfo := accountManager.getAccount(accountName))) {
                (status, message) = (Unauthorized, $"Account '{accountName}' is missing");
                break;
            }

            if (accountInfo.webApps.contains(deployment)) {
                (status, message) = (Conflict, $"Deployment already exists: '{deployment}'");
                break;
            }

            if (!accountInfo.modules.contains(moduleName)) {
                (status, message) = (NotFound, $"Module is missing: '{moduleName}'");
                break;
            }

            // compute the full host name (e.g. "shop.acme.com.xqiz.it")
            String hostName = $"{deployment}.{accountName}.{baseDomain}";

            ErrorLog errors = new ErrorLog();
            if (!hostManager.ensureCertificate(accountName, hostName, errors)) {
                (status, message) = (Conflict, errors.collectErrors());
                break;
            }

            accountManager.addOrUpdateWebApp(accountName,
                new WebAppInfo(deployment, moduleName, hostName, False));
        } while (False);

        return new SimpleResponse(status, bytes=message?.utf8() : Null);
    }

    /**
     * Handle a request to unregister a deployment.
     */
    @Delete("/unregister/{deployment}")
    SimpleResponse unregister(String deployment) {
        SimpleResponse response = stopWebApp(deployment);
        if (response.status == OK, WebHost webHost := hostManager.getWebHost(deployment)) {
            hostManager.removeWebHost(webHost);
        }

        // TODO: revoke the certificate?
        accountManager.removeWebApp(accountName, deployment);

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
                (status, message) = (Unauthorized, $"Account '{accountName}' is missing");
                break;
            }

            WebAppInfo webAppInfo;
            if (!(webAppInfo := accountInfo.webApps.get(deployment))) {
                (status, message) = (NotFound, $"Invalid deployment '{deployment}'");
                break;
            }

            ErrorLog errors = new ErrorLog();
            if (WebHost webHost := hostManager.getWebHost(deployment)) {
                if (webHost.activate(httpServer, True, errors)) {
                    accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(True));
                } else {
                    (status, message) = (Conflict, errors.collectErrors());
                    hostManager.removeWebHost(webHost);
                    webHost.deactivate(True);
                }
                break;
            }

            if (WebHost webHost := hostManager.createWebHost(httpServer, accountName, webAppInfo, errors)) {
                if (webHost.activate(httpServer, True, errors)) {
                    accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(True));
                } else {
                    (status, message) = (Conflict, errors.collectErrors());
                    hostManager.removeWebHost(webHost);
                    webHost.deactivate(True);
                }
            } else {
                (status, message) = (Conflict, errors.collectErrors());
            }
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

            webHost.deactivate(True);
            accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(False));
        } while (False);

        return new SimpleResponse(status, bytes=message?.utf8() : Null);
    }
}