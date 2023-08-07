import common.model2.AccountInfo;
import common.model2.ModuleInfo;
import common.model2.WebAppInfo;
import common.model2.WebAppOperationResult;


/**
 * The account management API.
 */
interface AccountManager2 {
    /**
     * Retrieve an 'AccountInfo' for the specified name.
     *
     * @param accountName  the account name
     *
     * @return True iff there is an AccountInfo
     * @return (optional) the AccountInfo
     */
    conditional AccountInfo getAccount(String accountName);

    /**
     * Add the specified module to the account or update the module information
     *
     * @param accountName  the account name
     * @param moduleName   the module info
     */
    void addOrUpdateModule(String accountName, ModuleInfo moduleInfo);

    /**
     * Remove the specified module from the account.
     *
     * @param accountName  the account name
     * @param moduleName   the module name
     */
    void removeModule(String accountName, String moduleName);

    /**
     * Add the specified web application to the account
     *
     * @param accountName  the account name
     * @param webAppInfo   the web application info
     */
    void addWebApp(String accountName, WebAppInfo webAppInfo);

    /**
     * Remove the specified web application from the account.
     *
     * @param accountName  the account name
     * @param webAppName   the web application name
     */
    void removeWebApp(String accountName, String webAppName);

    /**
     * Start the specified web application from the account.
     *
     * @param accountName  the account name
     * @param domain       the domain of the web application
     */
    (WebAppOperationResult, String) startWebApp(String accountName, String domain);

    /**
     * Stop the specified web application from the account.
     *
     * @param accountName  the account name
     * @param domain       the domain of the web application
     */
    (WebAppOperationResult, String) stopWebApp(String accountName, String domain);

    /**
     * Obtain an available HTTP port within the specified range. The returned value will always be
     * an even number and the next (odd) value should be used for a corresponding HTTPS port.
     *
     * @param  range  the range to allocate the port within
     *
     * @return True iff the port is allocated
     * @return (optional) the allocated port
     */
     conditional UInt16 allocatePort(Range<UInt16> range);


    // ----- lifecycle -------------------------------------------------------------------------------------------------

    /**
     * Shutdown all account services.
     */
    void shutdown();
}