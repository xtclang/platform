import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.WebAppInfo;
import common.model.DependentModule;

import web.*;
import web.http.FormDataFile;
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
     * Returns a JSON map of all webapps for given account.
     */
    @Get("all")
    Map<String, WebAppInfo> getAvailable() {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return new ListMap();
        }
        return accountInfo.webApps;
    }

    /**
     * Handles a request to register a webapp from module
     * Assumptions
     *  - many webapps can be registered from the same module with different domains
     *  - a domain has one and only one webapp
     *
     */
    @Post("/register/{domain}/{moduleName}")
    HttpStatus register(String domain, String moduleName) {

        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return HttpStatus.Unauthorized;
        }

        Boolean domainTaken = accountInfo.webApps.values.iterator()
            .map(webappInfo -> webappInfo.domain)
            .untilAny(appDomain -> appDomain == domain);

        Boolean moduleExists = accountInfo.modules.keys.iterator()
            .untilAny(name -> name == moduleName);

        if (domainTaken) {
            return HttpStatus.Conflict;
        }

        if (!moduleExists) {
            return HttpStatus.NotFound;
        }

        (String hostName, String bindAddr, UInt16 httpPort, UInt16 httpsPort) = getAuthority(domain);
        accountManager.addOrUpdateWebApp(
                        accountName,
                        new WebAppInfo(moduleName, domain, hostName, bindAddr, httpPort, httpsPort, False)
                    );
        return HttpStatus.OK;
    }

    /**
     * Handles a request to unregister a domain
     */
    @Delete("/unregister/{domain}")
    HttpStatus unregister(String domain) {
        AccountInfo accountInfo;
        if (!(accountInfo := accountManager.getAccount(accountName))) {
            return HttpStatus.Unauthorized;
        }

        Boolean domainRegistered = accountInfo.webApps.values.iterator()
            .map(webappInfo -> webappInfo.domain)
            .untilAny(appDomain -> appDomain == domain);

        if (!domainRegistered) {
            return HttpStatus.NotFound;
        }

        accountManager.removeWebApp(accountName, domain);
        return HttpStatus.OK;
    }

    /**
     * Handles a request to unregister a domain
     */
    @Post("/start/{domain}")
    SimpleResponse startWebApp(String domain) {

        @Inject Console console;
        console.print("Got start request for " + domain);

        HttpStatus  status  = OK;
        String?     message = Null;
        do {
            AccountInfo accountInfo;
            if (!(accountInfo := accountManager.getAccount(accountName))) {
                (status, message) = (NotFound, $"Account '{accountName}' is missing");
                break;
            }

            WebAppInfo webAppInfo;
            if (!(webAppInfo := accountInfo.webApps.get(domain))) {
                (status, message) = (NotFound, $"No application registered for '{domain}' domain");
                break;
            }

            WebHost webHost;
            if (webHost := hostManager.getWebHost(domain)) {
                if (!webAppInfo.active) {
                    console.print($"Host found for {domain} but domain is marked as inactive. Fixing it.");
                    accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(True));
                    }
                (status, message) = (OK, $"The application is already running");
                break;
                }

            ErrorLog errors = new ErrorLog();
            if (!(webHost := hostManager.ensureWebHost(accountName, webAppInfo, errors))) {
                (status, message) = (InternalServerError, errors.toString());
                break;
            }

            accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(True));
        } while (False);

        console.print($"{status=} {message=}");

        return new SimpleResponse(status, bytes=message?.utf8() : Null);
    }

//    /**
//     * Show the console's content (currently unused).
//     */
//    @Get("report/{domain}")
//    @Produces(Text)
//    String report(String domain) {
//        if (WebHost webHost := hostManager.getWebHost(domain)) {
//            File consoleFile = webHost.homeDir.fileFor("console.log");
//            if (consoleFile.exists && consoleFile.size > 0) {
//                return consoleFile.contents.unpackUtf8();
//            }
//        }
//        return "[empty]";
//    }
//
    /**
     * Handles a request to unregister a domain
     */
    @Post("/stop/{domain}")
    SimpleResponse stopWebApp(String domain) {

        @Inject Console console;
        console.print("Got stop request for " + domain);

        HttpStatus  status  = OK;
        String?     message = Null;
        do {
            AccountInfo accountInfo;
            if (!(accountInfo := accountManager.getAccount(accountName))) {
                (status, message) = (NotFound, $"Account '{accountName}' is missing");
                break;
            }

            WebAppInfo webAppInfo;
            if (!(webAppInfo := accountInfo.webApps.get(domain))) {
                (status, message) = (NotFound, $"No application registered for '{domain}' domain");
                break;
            }

            WebHost webHost;
            if (!(webHost := hostManager.getWebHost(domain))) {
                if (webAppInfo.active) {
                    console.print($"No host for {domain} but domain is marked as active. Fixing it.");
                    accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(False));
                    }
                (status, message) = (OK, "The application is not running");
                break;
            }

            hostManager.removeWebHost(webHost);
            webHost.close();
            accountManager.addOrUpdateWebApp(accountName, webAppInfo.updateStatus(False));
        } while (False);

        console.print($"{status=} {message=}");

        return new SimpleResponse(status, bytes=message?.utf8() : Null);
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