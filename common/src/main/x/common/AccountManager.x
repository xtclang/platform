import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.WebAppInfo;


/**
 * The account management API.
 */
interface AccountManager {
    /**
     * Retrieve all known accounts.
     */
    AccountInfo[] getAccounts();

    /**
     * Retrieve accounts for the specified user.
     *
     * @param userName  the user name
     *
     * @return a list of account names for the specified user
     */
    Collection<String> getAccounts(String userName);

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
     * Add the specified web application to the account or update tis info.
     *
     * @param accountName  the account name
     * @param webAppInfo   the web application info
     */
    void addOrUpdateWebApp(String accountName, WebAppInfo webAppInfo);

    /**
     * Remove the specified web application from the account.
     *
     * @param accountName  the account name
     * @param webAppName   the web application name
     */
    void removeWebApp(String accountName, String webAppName);


    // ----- lifecycle -----------------------------------------------------------------------------

    /**
     * Shutdown all account services.
     */
    void shutdown();
}