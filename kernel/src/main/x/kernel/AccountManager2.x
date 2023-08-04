import ecstasy.text.Log;

import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import common.DbHost;

import common.model2.AccountId;
import common.model2.AccountInfo;
import common.model2.ModuleInfo;
import common.model2.UserId;
import common.model2.UserInfo;
import common.model2.WebAppInfo;

import common.utils;

import oodb.DBMap;
import oodb.DBUser;

/**
 * The module for basic hosting functionality.
 */
service AccountManager2
        implements common.AccountManager2 {

    @Unassigned
    DbHost platformDbHost;

    @Unassigned
    platformDB2.Connection dbConnection;

    /**
     * Initialize the DB connection.
     *
     * @param repository  the core [ModuleRepository]
     * @param dbDir       the directory for the platform database (e.g. "~/xqiz.it/platform/")
     * @param buildDir    the directory to place auto-generated modules at  (e.g. "~/xqiz.it/platform/build")
     * @param errors      the error log
     */
    void initDB(ModuleRepository repository, Directory dbDir, Directory buildDir, Log errors) {
        repository = new LinkedRepository([new DirRepository(buildDir), repository].freeze(True));
        assert platformDbHost := utils.createDbHost(repository, dbDir, "platformDB2.xqiz.it", "jsondb", errors);

        DBUser user = new oodb.model.User(1, "admin");
        dbConnection = platformDbHost.ensureDatabase()(user).as(platformDB2.Connection);

        // TEMPORARY: TODO remove after "add user" functionality is implemented
        DBMap<AccountId, AccountInfo> accounts = dbConnection.accounts;
        DBMap<UserId, UserInfo>       users    = dbConnection.users;
        if (!accounts.contains(1)) {
            UserInfo admin = new UserInfo(1, "admin", "admin@acme.com");
            users.put(1, admin);
            accounts.put(1, new AccountInfo(1, "acme", [], [], Map:[1 = Admin]));
        }

        if (!accounts.contains(2)) {
            UserInfo admin = new UserInfo(2, "admin", "admin@cvs.com");
            users.put(2, admin);
            accounts.put(2, new AccountInfo(2, "cvs", [], [], Map:[2 = Admin]));
        }
    }

    @Override
    conditional AccountInfo getAccount(String accountName) {
        return dbConnection.accounts.values.any(info -> info.name == accountName);
    }

    @Override
    void addOrUpdateModule(String accountName, ModuleInfo moduleInfo) {
        using (val tx = dbConnection.createTransaction()) {
            if (AccountInfo accountInfo := getAccount(accountName)) {
                tx.accounts.put(accountInfo.id, accountInfo.addModule(moduleInfo));
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
    void addWebApp(String accountName, WebAppInfo webAppInfo) {
        using (val tx = dbConnection.createTransaction()) {
            String domain = webAppInfo.domain;
            if (AccountInfo accountInfo := getAccount(accountName)) {

                assert !accountInfo.webApps.contains(domain);
                tx.accounts.put(accountInfo.id, accountInfo.addWebApp(webAppInfo));
                // update the "allocatedPorts" table
                dbConnection.allocatedPorts.put(webAppInfo.httpPort, accountInfo.id);
            }
        }
    }

    @Override
    void removeWebApp(String accountName, String appName) {
        using (val tx = dbConnection.createTransaction()) {
            if (
                AccountInfo accountInfo := getAccount(accountName),
                WebAppInfo webAppInfo := accountInfo.webApps.get(appName)
                ) {

                tx.accounts.put(accountInfo.id, accountInfo.removeModule(appName));
                // update the "allocatedPorts" table
                dbConnection.allocatedPorts.remove(webAppInfo.httpPort);
            }
        }
    }


    @Override
    conditional UInt16 allocatePort(Range<UInt16> range) {
        using (val tx = dbConnection.createTransaction()) {
            DBMap<UInt16, AccountId> allocatedPorts = dbConnection.allocatedPorts;

            for (UInt16 port = range.lowerBound; port < range.upperBound; port += 2) {
                if (!allocatedPorts.contains(port)) {
                    return True, port;
                }
            }
            return False;
        }
    }

    @Override
    void shutdown() {
        platformDbHost.closeDatabase();
    }
}