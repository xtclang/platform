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
                        new WebAppInfo(moduleName, domain, hostName, bindAddr, httpPort, httpsPort)
                    );
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