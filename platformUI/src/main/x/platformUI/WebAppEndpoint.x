import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import ecstasy.reflect.ModuleTemplate;

import web.*;
import web.http.FormDataFile;
import web.responses.SimpleResponse;

import common.model2.AccountInfo;
import common.model2.ModuleInfo;
import common.model2.WebAppInfo;
import common.model2.DependentModule;
import common.model2.WebAppOperationResult;

import common.ErrorLog;
import common.utils;

/**
 * Dedicated service for operations on WebApps
 */
@WebService("/webapp")
@LoginRequired
service WebAppEndpoint() {

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
        accountManager.addWebApp(
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
        console.print ("Got start request for " + domain);

        ErrorLog errorLog = new ErrorLog();
        (WebAppOperationResult result, String message) = accountManager.startWebApp(accountName, domain);

        console.print ("Result: " + result);
        console.print ("Message: " + message);

        return toSimpleResponse (result, message);
    }

    /**
     * Handles a request to unregister a domain
     */
    @Post("/stop/{domain}")
    SimpleResponse stopWebApp(String domain) {

        @Inject Console console;
        console.print ("Got stop request for " + domain);

        ErrorLog errorLog = new ErrorLog();
        (WebAppOperationResult result, String message) = accountManager.stopWebApp(accountName, domain);

        return toSimpleResponse (result, message);
    }


    // ----- helpers -------------------------------------------------------------------------------


    SimpleResponse toSimpleResponse (WebAppOperationResult result, String message) {
        @Inject Console console;
        console.print ($"Result: {result}");
        console.print ($"Message: {message}");

        /*
         * This is not working and I have no idea why!
         * No matter what `result` is, it always goes to `default`
         */
//        switch (result) {
//            case OK:
//                console.print (" --- OK");
//                return new SimpleResponse(OK);
//            case NotFound:
//                console.print (" --- NotFound");
//                return new SimpleResponse(NotFound, Null, message.utf8());
//            case Conflict:
//                console.print (" --- Conflict");
//                return new SimpleResponse(Conflict, Null, message.utf8());
//            case Error:
//                console.print (" --- Error");
//                return new SimpleResponse(InternalServerError, Null, message.utf8());
//            default :
//                console.print (" --- default");
//                return new SimpleResponse(InternalServerError, Null, message.utf8());
//        }

        if (result == OK) {
            console.print (" --- OK");
            return new SimpleResponse(OK, Null, message.utf8());
        }
        if (result == NotFound) {
            console.print (" --- NotFound");
            return new SimpleResponse(NotFound, Null, message.utf8());
        }
        if (result == Conflict) {
            console.print (" --- Conflict");
            return new SimpleResponse(Conflict, Null, message.utf8());
        }

        console.print (" --- Error");
        return new SimpleResponse(InternalServerError, Null, message.utf8());


    }

    /**
     * Get the host name and ports for the specified domain.
     */
    (String hostName, String bindAddr, UInt16 httpPort, UInt16 httpsPort) getAuthority(String domain) {
        assert UInt16 httpPort := accountManager.allocatePort(ControllerConfig.userPorts);

        return ControllerConfig.hostName, ControllerConfig.bindAddr, httpPort, httpPort+1;
    }


}