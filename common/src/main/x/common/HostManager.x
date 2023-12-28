import ecstasy.text.Log;

import common.model.WebAppInfo;

import xenia.HttpServer;


/**
 * The Host Manager API.
 */
interface HostManager {
    // ----- WebHost management --------------------------------------------------------------------

    /**
     * Ensure a users directory for the specified account (e.g. "~/xqiz.it/users/acme.com").
     */
    Directory ensureUserDirectory(String accountName);

    /**
     * Ensure a user "lib" directory for the specified account (e.g. "~/xqiz.it/users/acme.com/lib").
     */
    Directory ensureUserLibDirectory(String accountName) {
        return ensureUserDirectory(accountName).dirFor("lib");
    }

    /**
     * Ensure a user "host" directory for the specified account (e.g. "~/xqiz.it/users/acme.com/host").
     */
    Directory ensureUserHostDirectory(String accountName) {
        return ensureUserDirectory(accountName).dirFor("host");
    }

    /**
     * Ensure there is a keystore for the specified account that contains a private key and a
     * certificate for the specified host name and a symmetrical key to be used for cookie encryption.
     *
     * @return True iff the certificate exists and is valid; otherwise an error is logged
     */
    Boolean ensureCertificate(String accountName, String hostName, Log errors);

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
     * @param errors      the error log
     *
     * @return True iff the WebHost was successfully created
     * @return (optional) the WebHost for the newly loaded Container
     */
    conditional WebHost createWebHost(HttpServer httpServer, String accountName,
                                      WebAppInfo webAppInfo, Log errors);

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