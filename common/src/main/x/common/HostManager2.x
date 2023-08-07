import ecstasy.text.Log;

import common.model2.WebAppInfo;


/**
 * The Host Manager API.
 */
interface HostManager2 {
    // ----- WebHost management ----------------------------------------------------------------------------------------

    /**
     * Ensure a user "lib" directory for the specified account (e.g. "~/xqiz.it/users/acme/lib").
     */
    Directory ensureUserLibDirectory(String accountName);

    /**
     * Retrieve a 'WebHost' for the specified domain.
     *
     * @return True iff there is a WebHost for the specified domain
     * @return (optional) the WebHost
     */
    conditional WebHost2 getWebHost(String domain);

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
    conditional WebHost2 ensureWebHost(String accountName, WebAppInfo webAppInfo, Log errors);

    /**
     * Remove the specified WebHost.
     */
    void removeWebHost(WebHost2 webHost);


    // ----- lifecycle -------------------------------------------------------------------------------------------------

    /**
     * Shutdown all hosted services.
     */
    void shutdown();
}