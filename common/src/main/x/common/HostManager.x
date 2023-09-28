import ecstasy.text.Log;

import common.model.WebAppInfo;


/**
 * The Host Manager API.
 */
interface HostManager {
    // ----- WebHost management ----------------------------------------------------------------------------------------

    /**
     * Ensure a user "lib" directory for the specified account (e.g. "~/xqiz.it/users/acme/lib").
     */
    Directory ensureUserLibDirectory(String accountName);

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
     * @param account     the account name
     * @param webAppInfo  the web application info
     * @param errors      the error log
     *
     * @return True iff the WebHost was successfully created
     * @return (optional) the WebHost for the newly loaded Container
     */
    conditional WebHost ensureWebHost(String accountName, WebAppInfo webAppInfo, Log errors);

    /**
     * Remove the specified WebHost.
     */
    void removeWebHost(WebHost webHost);


    // ----- lifecycle -------------------------------------------------------------------------------------------------

    /**
     * Shutdown all hosted services.
     */
    void shutdown();
}