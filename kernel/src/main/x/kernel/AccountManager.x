import ecstasy.text.Log;

import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import common.DbHost;

import common.model.AccountId;
import common.model.AccountInfo;
import common.model.ModuleInfo;
import common.model.UserId;
import common.model.UserInfo;
import common.model.WebModuleInfo;

import common.utils;

/**
 * The module for basic hosting functionality.
 */
service AccountManager
        implements common.AccountManager {

    @Unassigned
    DbHost platformDbHost;

    @Unassigned
    platformDB.Connection dbConnection;

    /**
     * Initialize the DB connection.
     *
     * @param repository  the core [ModuleRepository]
     * @param dbDir       the directory for the platform database (e.g. "~/xqiz.it/platform/")
     * @param buildDir    the directory to place auto-generated modules at  (e.g. "~/xqiz.it/platform/build")
     * @param errors      the error log
     */
    void initDB(ModuleRepository repository, Directory dbDir, Directory buildDir, Log errors) {
        import oodb.DBMap;
        import oodb.DBUser;

        repository = new LinkedRepository([new DirRepository(buildDir), repository].freeze(True));
        assert platformDbHost := utils.createDbHost(repository, dbDir, "platformDB.xqiz.it", "jsondb", errors);

        DBUser user = new oodb.model.User(1, "admin");
        dbConnection = platformDbHost.ensureDatabase()(user).as(platformDB.Connection);

        DBMap<AccountId, AccountInfo> accounts = dbConnection.accounts;
        DBMap<UserId, UserInfo>       users    = dbConnection.users;
        if (!accounts.contains(1)) {
            UserInfo admin = new UserInfo(1, "admin", "admin@acme.com");
            users.put(1, admin);
            accounts.put(1, new AccountInfo(1, "acme", [], Map:[1 = Admin]));
        }

        if (!accounts.contains(2)) {
            UserInfo admin = new UserInfo(2, "admin", "admin@cvs.com");
            users.put(2, admin);
            accounts.put(2, new AccountInfo(2, "cvs", [], Map:[2 = Admin]));
        }
    }

    @Override
    conditional AccountInfo getAccount(String accountName) {
        return dbConnection.accounts.values.any(info -> info.name == accountName);
    }

    @Override
    void addModule(String accountName, ModuleInfo moduleInfo) {
        using (val tx = dbConnection.createTransaction()) {
            String appName = moduleInfo.name;
            if (AccountInfo info := getAccount(accountName)) {
                if (info.modules.contains(appName)) {
                    info = info.removeModule(appName);
                }
                tx.accounts.put(info.id, info.addModule(moduleInfo));
            }
        }
    }

    @Override
    void removeModule(String accountName, String appName) {
        using (val tx = dbConnection.createTransaction()) {
            if (AccountInfo info := getAccount(accountName), info.modules.contains(appName)) {
                tx.accounts.put(info.id, info.removeModule(appName));
            }
        }
    }

    @Override
    void shutdown() {
        platformDbHost.closeDatabase();
    }
}