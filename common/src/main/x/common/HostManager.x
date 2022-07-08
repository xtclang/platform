import common.model.AccountInfo;

import ecstasy.text.Log;

/**
 * The Host Manager API.
 */
interface HostManager
    {
    // ----- WebHost management ----------------------------------------------------------------------------------------

    /**
     * Retrieve a 'WebHost' for the specified domain.
     *
     * @return True iff there is a WebHost for the specified domain
     * @return (optional) the WebHost
     */
    conditional WebHost getWebHost(String domain);

    /**
     * Create a 'WebHost' for the specified application module.
     *
     * @param userDir  the user 'Directory'
     * @param appName  the application module name
     * @param domain   a sub-domain to use for the application (only for web applications)
     * @param errors   the error log
     *
     * @return True iff the WebHost was successfully created
     * @return (optional) the WebHost for the newly loaded Container
     */
    conditional WebHost createWebHost(Directory userDir, String appName, String domain, Log errors);

    /**
     * Remove the specified WebHost.
     */
    void removeWebHost(WebHost webHost);


    // ----- Account management ----------------------------------------------------------------------------------------

    /**
     * Retrieve an 'AccountInfo' for the specified name.
     *
     * @return True iff there is an AccountInfo
     * @return (optional) the AccountInfo
     */
    conditional AccountInfo getAccount(String accountName);

    /**
     * Store the account info.
     *
     * @param the AccountInfo
     */
    void storeAccount(AccountInfo info);


    // ----- lifecycle -------------------------------------------------------------------------------------------------

    /**
     * Shutdown all hosting services.
     */
    void shutdown();
    }