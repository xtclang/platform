import ecstasy.text.Log;

import common.model.WebAppInfo;

import crypto.CryptoPassword;

import xenia.HttpServer;


/**
 * The Host Manager API.
 */
interface HostManager {
    // ----- WebHost management --------------------------------------------------------------------

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
     * Ensure there is a keystore for the specified web app that contains a private key and a
     * certificate for the specified host name and a symmetrical key to be used for cookie encryption.
     *
     * @param accountName  the account the web app belongs to
     * @param deployment   the deployment name
     * @param hostName     the application host name
     * @param pwd          the password to use for the keystore
     * @param errors       the logger to report errors to
     *
     * @return True iff the certificate exists and is valid; otherwise an error is logged
     */
    Boolean ensureCertificate(String accountName, String deployment, String hostName,
                              CryptoPassword pwd, Log errors);

    /**
     * Retrieve a 'WebHost' for the specified deployment.
     *
     * @return True iff there is a WebHost for the specified deployment
     * @return (optional) the WebHost
     */
    conditional WebHost getWebHost(String deployment);

    /**
     * Create a 'WebHost' for the specified application module.
     *
     * @param httpServer  the HttpServer to use
     * @param account     the account name
     * @param webAppInfo  the web application info
     * @param pwd         the password to use for the keystore
     * @param errors      the error log
     *
     * @return True iff the WebHost was successfully created
     * @return (optional) the WebHost for the newly loaded Container
     */
    conditional WebHost createWebHost(HttpServer httpServer, String accountName,
                                      WebAppInfo webAppInfo, CryptoPassword pwd, Log errors);

    /**
     * Remove the specified WebHost.
     */
    void removeWebHost(WebHost webHost);


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