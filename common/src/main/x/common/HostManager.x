import ecstasy.text.Log;

import common.model.DbAppInfo;
import common.model.WebAppInfo;

import crypto.Certificate;
import crypto.CryptoPassword;


/**
 * The Host Manager API.
 */
interface HostManager {
    // ----- WebHost management --------------------------------------------------------------------

    /**
     * The stub WebApp, which is used to serve requests when a deployments have been registered, but
     * either not yet deployed or deactivated.
     */
    @RO web.WebApp stubApp;

    /**
     * Ensure an account home directory for the specified account (e.g. "~/xqiz.it/accounts/self").
     */
    Directory ensureAccountHomeDirectory(String accountName);

    /**
     * Ensure a "lib" directory for the specified account (e.g. "~/xqiz.it/accounts/self/lib").
     * This is the repository for Ecstasy modules that belong to the account.
     */
    Directory ensureAccountLibDirectory(String accountName) {
        return ensureAccountHomeDirectory(accountName).dirFor("lib").ensure();
    }

    /**
     * Ensure a "build" directory for the specified account (e.g. "~/xqiz.it/accounts/self/build").
     * This is the internal storage for files and modules that are auto-generated for the account.
     */
    Directory ensureAccountBuildDirectory(String accountName) {
        return ensureAccountHomeDirectory(accountName).dirFor("build").ensure();
    }

    /**
     * Ensure a "home" directory for the specified account and deployment
     * (e.g. "~/xqiz.it/accounts/self/deploy/welcome.org").
     *
     * @return the deployment home directory
     * @return True iff the home directory has just been created; False otherwise
     */
    (Directory, Boolean) ensureDeploymentHomeDirectory(String accountName, String deployment) {
        Directory dirHome = ensureAccountHomeDirectory(accountName).dirFor($"deploy/{deployment}");
        return dirHome.exists
                ? (dirHome, False)
                : (dirHome.ensure(), True);
    }

    /**
     * Retrieve an [AppHost] for the specified deployment name
     *
     * @return True iff there is an AppHost for the specified deployment
     * @return (optional) the AppHost
     */
    conditional AppHost getHost(String deployment);

    /**
     * Remove the specified [AppHost].
     */
    void removeHost(AppHost host);


    // ----- WebApp management ---------------------------------------------------------------------

    /**
     * Ensure there is a keystore for the specified web app that contains a private key, a
     * certificate for the application host name and a symmetrical key for cookie encryption.
     *
     * @param accountName  the account the web app belongs to
     * @param webAppInfo   the web application info
     * @param pwd          the password to use for the keystore
     * @param errors       the logger to report errors to
     *
     * @return True iff the certificate exists and is valid; otherwise an error is logged
     * @return (conditional) the certificate
     */
    conditional Certificate ensureCertificate(String accountName, WebAppInfo appInfo,
                                              CryptoPassword pwd, Log errors);

    /**
     * Add a stub route for the specified web app.
     *
     * @param accountName  the account name
     * @param webAppInfo   the web application info
     * @param pwd          (optional) the password to use for the keystore
     */
    void addStubRoute(String accountName, WebAppInfo appInfo, CryptoPassword? pwd = Null);

    /**
     * Retrieve a [WebHost] for the specified deployment.
     *
     * @return True iff there is a WebHost for the specified deployment
     * @return (conditional) the WebHost
     */
    conditional WebHost getWebHost(String deployment) {
        if (AppHost host := getHost(deployment), host.is(WebHost)){
            return True, host;
        }
        return False;
    }

    /**
     * Create a [WebHost] for the specified application module. If the `WebHost` cannot be created
     * successfully, or if the application is not [autoStart](WebAppInfo.autoStart), the "stub" web
     * application will be installed.
     *
     * @param accountName  the account name
     * @param webAppInfo   the web application info
     * @param pwd          the password to use for the keystore
     * @param errors       the error log
     *
     * @return True iff the WebHost was successfully created
     * @return (conditional) the WebHost for the newly loaded Container
     */
    conditional WebHost createWebHost(String accountName, WebAppInfo webAppInfo, CryptoPassword pwd,
                                      Log errors);

    /**
     * Remove the specified deployment.
     */
    void removeWebDeployment(String accountName, WebAppInfo webAppInfo, CryptoPassword pwd);


    // ----- DB App management ---------------------------------------------------------------------

    /**
     * Retrieve a [DbHost] for the specified deployment.
     *
     * @return True iff there is a DbHost for the specified deployment
     * @return (optional) the DbHost
     */
    conditional DbHost getDbHost(String deployment) {
        if (AppHost host := getHost(deployment), host.is(DbHost)){
            return True, host;
        }
        return False;
    }

    /**
     * Create a [DbHost] for the specified application module.
     *
     * @param accountName  the account name
     * @param dbAppInfo    the db application info
     *
     * @return True iff the DbHost was successfully created
     * @return (optional) the DbHost for the newly loaded Container
     */
    conditional DbHost createDbHost(String accountName, DbAppInfo dbAppInfo, Log errors);

    /**
     * Remove the specified deployment.
     */
    void removeDbDeployment(String accountName, DbAppInfo dbAppInfo);


    // ----- lifecycle -----------------------------------------------------------------------------

    /**
     * Shutdown all hosted services. Regardless of the outcome, when this method returns no new
     * request will be accepted for processing.
     *
     * @param force  (optional) pass True to force the shutdown
     *
     * @return False iff there any pending requests and some services are still shutting down.
     *         in which case the caller is supposed to either "force" the shutdown or repeat it
     *         within a reasonable duration of time and for a reasonable number of times
     */
    Boolean shutdown(Boolean force = False);
}