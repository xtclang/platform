import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.ModuleInfo;
import common.model.UserId;
import common.model.UserInfo;

import crypto.CryptoPassword;


/**
 * The account management API.
 *
 * Note 1: When [AccountInfo](accounts) are created, they are assigned an internal id. The
 *         {UserInfo}(users) are created using the internal ids generated by the DBRealm. Neither
 *         one can ever be changed.
 * Note 2: There is no "removal" of an account, only "deactivation". The system may purge
 *         inactive accounts at some point in the future. Account name can be changed, assuming
 *         the name is available at that time.
 * Note 3: There is no "removal" of a user, only "deactivation". The system may purge
 *         inactive users at some point in the future. User name and/or email can be changed,
 *         assuming there is no conflict at that time.
 */
interface AccountManager {
    // ----- AccountInfo management ----------------------------------------------------------------

    /**
     * Retrieve all known accounts.
     */
    AccountInfo[] getAccounts();

    /**
     * Retrieve an 'AccountInfo' for the specified name.
     *
     * @param accountName  the account name
     *
     * @return True iff there is an account with the specified name
     * @return (conditional) the AccountInfo
     */
    conditional AccountInfo getAccount(String accountName);

    /**
     * Create an account for the specified name. Any additional account information could be changed
     * later using [updateAccount] API.
     *
     * @param accountName  the account name
     *
     * @return True iff the account name is not currently used
     * @return (conditional) the AccountInfo for the newly created account
     */
    conditional AccountInfo createAccount(String accountName);

    /**
     * Update the specified account.
     *
     * @param account  the AccountInfo object that contains updated information
     *
     * @return True iff the account info has been successfully updated; False if any information is
     *         invalid (e.g. the account name has changed, but the new one is not available)
     */
    Boolean updateAccount(AccountInfo account);

    /**
     * Retrieve accounts for the specified user.
     *
     * @param userName  the user name
     *
     * @return a list of accounts for the specified user
     */
    Collection<AccountInfo> getAccounts(String userName);

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
     * Add the specified application to the account or update tis info.
     *
     * @param accountName  the account name
     * @param appInfo      the application info
     */
    void addOrUpdateApp(String accountName, AppInfo appInfo);

    /**
     * Remove the specified web application from the account.
     *
     * @param accountName  the account name
     * @param deployment   the application deployment name
     */
    void removeApp(String accountName, String deployment);


    // ----- UserInfo management -------------------------------------------------------------------

    /**
     * Get a user for the specified name.
     *
     * @param userName  the user name
     *
     * @return True iff there is a user the specified name
     * @return (conditional) the UserInfo
     */
    conditional UserInfo getUser(String userName);

    /**
     * Ensure a user for the specified name and email.
     *
     * @param userId    the user id
     * @param userName  the user name
     * @param email     the user email address
     *
     * @return True iff the user name and email are not currently used
     * @return (conditional) the UserInfo for the newly created user
     */
    conditional UserInfo createUser(UserId id, String userName, String email);

    /**
     * Update the specified user.
     *
     * @param user  the UserInfo object that contains updated information
     *
     * @return True iff the user info has been successfully updated; False if any information is
     *         invalid (e.g. the user email has changed, but the new one is not available)
     */
    Boolean updateUser(UserInfo user);


    // ----- secrets management --------------------------------------------------------------------

    /**
     * Encrypt the specified password.
     */
    String encrypt(String password);

    /**
     * Decrypt the specified text. Note that there is no way to obtain the unencrypted password
     * value from the returned `CryptoPassword`, it can be used to access corresponding keystore.
     */
    CryptoPassword decrypt(String text);


    // ----- lifecycle -----------------------------------------------------------------------------

    /**
     * Shutdown all account services.
     */
    void shutdown();
}