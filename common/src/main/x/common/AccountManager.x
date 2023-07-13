import common.model.AccountInfo;
import common.model.ModuleInfo;

/**
 * The account management API.
 */
interface AccountManager {
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
     * Add the specified module to the account.
     *
     * @param accountName  the account name
     * @param moduleName   the module info
     */
    void addModule(String accountName, ModuleInfo moduleInfo);

    /**
     * Remove the specified module from the account.
     *
     * @param accountName  the account name
     * @param moduleName   the module name
     */
    void removeModule(String accountName, String moduleName);

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