import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.WebAppInfo;

import crypto.CryptoPassword;

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
     * Return a JSON map of all webapps for all webapps for given account.
     */
    @Get("status")
    Map<String, WebAppInfo> checkStatus() {
        if (AccountInfo accountInfo := accountManager.getAccount(accountName)) {
            HashMap<String, WebAppInfo> status = new HashMap();
            for ((String deployment, WebAppInfo info) : accountInfo.webApps) {
                if (WebHost webHost := hostManager.getWebHost(deployment)) {
                    info = info.updateStatus(webHost.active);
                }
                status.put(deployment, info.redact());
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
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(Unauthorized, $"Account '{accountName}' is missing");
        }

        // compute the full host name (e.g. "welcome.localhost.xqiz.it")
        String hostName = $"{deployment}.{baseDomain}";

        if (hostName.equals(httpServer.bindAddr) || accountInfo.webApps.contains(deployment)) {
            return new SimpleResponse(Conflict, $"Deployment already exists: '{deployment}'");
        }

        if (!accountInfo.modules.contains(moduleName)) {
            return new SimpleResponse(NotFound, $"Module is missing: '{moduleName}'");
        }

        // create a random password to be used to access the webapp's keystore
        @Inject Random random;
        String         encrypted = accountManager.encrypt(random.int128().toString());
        CryptoPassword cryptoPwd = accountManager.decrypt(encrypted);

        ErrorLog errors = new ErrorLog();
        if (!hostManager.ensureCertificate(accountName, deployment, hostName, cryptoPwd, errors)) {
            return new SimpleResponse(Conflict, errors.collectErrors());
        }

        accountManager.addOrUpdateWebApp(accountName,
                new WebAppInfo(deployment, moduleName, hostName, encrypted, False));

        // the deployment has been registered, but not yet started; give them something better
        // than "404: Page Not Found" to look at
        ControllerConfig.addStubRoute(hostName);
        return new SimpleResponse(OK);
    }

    /**
     * Handle a request to unregister a deployment.
     */
    @Delete("/unregister/{deployment}")
    SimpleResponse unregister(String deployment) {
        SimpleResponse response = stopWebApp(deployment);
        if (response.status != OK) {
            return response;
        }

        if (WebHost webHost := hostManager.getWebHost(deployment)) {
            hostManager.removeWebHost(webHost);
        }

        hostManager.removeDeployment(accountName, deployment);
        accountManager.removeWebApp(accountName, deployment);

        return new SimpleResponse(OK);
    }

    /**
     * Handle a request to start a deployment.
     */
    @Post("/start/{deployment}")
    SimpleResponse startWebApp(String deployment) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(Unauthorized, $"Account '{accountName}' is missing");
        }

        WebAppInfo webAppInfo;
        if (!(webAppInfo := accountInfo.webApps.get(deployment))) {
            return new SimpleResponse(NotFound, $"Invalid deployment '{deployment}'");
        }

        ErrorLog errors = new ErrorLog();
        WebHost  webHost;
        if (!(webHost := hostManager.getWebHost(deployment))) {
            // create a new WebHost
            if (!(webHost := hostManager.createWebHost(httpServer, accountName, webAppInfo,
                    accountManager.decrypt(webAppInfo.password), errors))) {
                return new SimpleResponse(Conflict, errors.collectErrors());
            }
        }

        if (webHost.activate(True, errors)) {
            accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(True));
            return new SimpleResponse(OK);
        } else {
            hostManager.removeWebHost(webHost);
            webHost.deactivate(True);
            return new SimpleResponse(Conflict, errors.collectErrors());
        }
    }

    /**
     * Show the app console's content.
     */
    @Get("appLog/{deployment}")
    @Produces(Text)
    String report(String deployment) {
        if (WebHost webHost := hostManager.getWebHost(deployment)) {
            File consoleFile = webHost.homeDir.fileFor("console.log");
            if (consoleFile.exists && consoleFile.size > 0) {
                return consoleFile.contents.unpackUtf8();
            }
        }
        return "[empty]";
    }

    /**
     * Handle a request to stop a deployment.
     */
    @Post("/stop/{deployment}")
    SimpleResponse stopWebApp(String deployment) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new SimpleResponse(NotFound, $"Account '{accountName}' is missing");
        }

        WebAppInfo webAppInfo;
        if (!(webAppInfo := accountInfo.webApps.get(deployment))) {
            return new SimpleResponse(NotFound, $"Invalid deployment '{deployment}'");
        }

        WebHost webHost;
        if (!(webHost := hostManager.getWebHost(deployment))) {
            if (webAppInfo.active) {
                // there's no host, but the deployment is marked as active; fix it
                accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(False));
                }
            return new SimpleResponse(OK, "The application is not running");
        }

        webHost.deactivate(True);
        accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(False));
        return new SimpleResponse(OK);
    }
}