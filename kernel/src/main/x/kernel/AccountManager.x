import ecstasy.text.Log;

import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import common.DbHost;

import common.model.AccountId;
import common.model.AccountInfo;
import common.model.AppInfo;
import common.model.ModuleInfo;
import common.model.UserId;
import common.model.UserInfo;

import common.utils;

import convert.formats.Base64Format;

import oodb.DBMap;
import oodb.DBUser;

import platformDB.Connection;


/**
 * The account management service.
 */
service AccountManager
        implements common.AccountManager {

    @Unassigned
    private DbHost platformDbHost;

    @Unassigned
    private Connection dbConnection;

    @Unassigned
    private Decryptor decryptor;

    /**
     * Initialize the service.
     *
     * @param repository  the core [ModuleRepository]
     * @param homeDir     the platform home directory (e.g. "~/xqiz.it/platform/host")
     * @param buildDir    the directory to place auto-generated modules at  (e.g. "~/xqiz.it/platform/build")
     * @param decryptor   the decryptor to use for encrypting/decrypting secrets
     * @param errors      the error log
     */
    Connection init(ModuleRepository repository, Directory homeDir, Directory buildDir,
              Decryptor decryptor, Log errors) {
        repository = new LinkedRepository([new DirRepository(buildDir), repository].freeze(True));
        assert this.platformDbHost := utils.createDbHost(repository, "platformDB.xqiz.it", Null,
                                                        "jsondb", homeDir, buildDir, errors);

        assert function oodb.Connection(DBUser) createConnection :=
            platformDbHost.activate(True, errors);

        this.dbConnection = createConnection(new oodb.model.User(1, "admin")).as(Connection);
        this.decryptor    = decryptor;
        return dbConnection;
    }

    /**
     * Check if the database is empty.
     */
    Boolean initialized.get() = !dbConnection.accounts.empty;


    // ----- common.AccountManager API -------------------------------------------------------------

    @Override
    AccountInfo[] getAccounts() = dbConnection.accounts.values.toArray(Constant);

    @Override
    conditional AccountInfo getAccount(String accountName) =
        dbConnection.accounts.values.any(info -> info.name == accountName);

    @Override
    conditional AccountInfo createAccount(String accountName) =
        dbConnection.accounts.create(accountName);

    @Override
    Boolean updateAccount(AccountInfo account) = dbConnection.accounts.update(account);

    @Override
    Collection<AccountInfo> getAccounts(String userName) {
        using (val tx = dbConnection.createTransaction()) {
            if (UserInfo userInfo := tx.users.values.any(info -> info.name == userName)) {
                UserId userId = userInfo.id;
                return tx.accounts.values.filter(info -> info.users.contains(userId))
                                         .toArray(Constant);
            }
        return [];
        }
    }

    @Override
    void addOrUpdateModule(String accountName, ModuleInfo moduleInfo) {
        using (val tx = dbConnection.createTransaction()) {
            if (AccountInfo accountInfo := getAccount(accountName)) {
                tx.accounts.put(accountInfo.id, accountInfo.addOrUpdateModule(moduleInfo));
            }
        }
    }

    @Override
    void removeModule(String accountName, String moduleName) {
        using (val tx = dbConnection.createTransaction()) {
            if (AccountInfo accountInfo := getAccount(accountName)) {
                tx.accounts.put(accountInfo.id, accountInfo.removeModule(moduleName));
            }
        }
    }

    @Override
    void addOrUpdateApp(String accountName, AppInfo appInfo) {
        using (val tx = dbConnection.createTransaction()) {
            if (AccountInfo accountInfo := getAccount(accountName)) {
                tx.accounts.put(accountInfo.id, accountInfo.addOrUpdateApp(appInfo));
            }
        }
    }

    @Override
    void removeApp(String accountName, String deployment) {
        using (val tx = dbConnection.createTransaction()) {
            if (AccountInfo accountInfo := getAccount(accountName)) {
                tx.accounts.put(accountInfo.id, accountInfo.removeApp(deployment));
            }
        }
    }

    @Override
    conditional UserInfo getUser(String userName) =
        dbConnection.users.values.any(info -> info.name == userName);

    @Override
    conditional UserInfo createUser(UserId userId, String userName, String email) =
        dbConnection.users.create(userId, userName, email);

    @Override
    Boolean updateUser(UserInfo user) =
        dbConnection.users.update(user);

    @Override
    String encrypt(String password) =
        Base64Format.Instance.encode(decryptor.encrypt(password.utf8()));

    @Override
    CryptoPassword decrypt(String text) {
        String password = decryptor.decrypt(Base64Format.Instance.decode(text)).unpackUtf8();
        CryptoPassword pwd = new NamedPassword("", password);
        return &pwd.maskAs(CryptoPassword);
    }

    @Override
    void shutdown() {
        platformDbHost.close();
    }
}