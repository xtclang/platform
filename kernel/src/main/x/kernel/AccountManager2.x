import ecstasy.text.Log;

import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;

import common.DbHost;
import common.WebHost2;
import common.HostManager2;

import common.model2.AccountId;
import common.model2.AccountInfo;
import common.model2.ModuleInfo;
import common.model2.UserId;
import common.model2.UserInfo;
import common.model2.WebAppInfo;
import common.model2.WebAppOperationResult;

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

    @Unassigned
    common.HostManager2 hostManager;

    /**
     * Initialize the service.
     *
     * @param repository  the core [ModuleRepository]
     * @param dbDir       the directory for the platform database (e.g. "~/xqiz.it/platform/")
     * @param buildDir    the directory to place auto-generated modules at  (e.g. "~/xqiz.it/platform/build")
     * @param errors      the error log
     */
    void init(ModuleRepository repository, Directory dbDir, Directory buildDir, HostManager2 hostManager, Log errors) {
        this.hostManager = hostManager;
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
    (WebAppOperationResult, String) startWebApp(String accountName, String domain) {

        @Inject Console console;
        console.print ($"Account manager trying to start app for {domain}");


        AccountInfo accountInfo;
        if (!(accountInfo := getAccount(accountName))) {
            return WebAppOperationResult.NotFound, $"Account '{accountName}' is missing";
        }

        WebAppInfo webAppInfo;
        if (!(webAppInfo := accountInfo.webApps.get(domain))) {
            return WebAppOperationResult.NotFound, $"No application registered for '{domain}' domain";
        }

        WebHost2 webHost;
        if (webHost := hostManager.getWebHost(domain)) {
            if (!webAppInfo.active) {
                console.print ($"Host found for {domain} but domain is marked as inactive. Fixing it.");
                using (val tx = dbConnection.createTransaction()) {
                    tx.accounts.put(accountInfo.id, accountInfo.updateWebAppStatus(domain, True));
                }
            }
            return WebAppOperationResult.Conflict, $"The application is already running";
        }

        ErrorLog errors = new ErrorLog();
        if (!(webHost := hostManager.ensureWebHost(accountName, webAppInfo, errors))) {
            return WebAppOperationResult.Error, errors.toString();
        }

        using (val tx = dbConnection.createTransaction()) {
            tx.accounts.put(accountInfo.id, accountInfo.updateWebAppStatus(domain, True));
        }

        return WebAppOperationResult.OK, "";

    }

    @Override
    (WebAppOperationResult, String) stopWebApp(String accountName, String domain) {
        @Inject Console console;
        console.print ($"Account manager trying to stop app for {domain}");

        AccountInfo accountInfo;
        if (!(accountInfo := getAccount(accountName))) {
            return WebAppOperationResult.NotFound, $"Account '{accountName}' is missing";
        }

        WebAppInfo webAppInfo;
        if (!(webAppInfo := accountInfo.webApps.get(domain))) {
            return WebAppOperationResult.NotFound, $"No application registered for '{domain}' domain";
        }

        WebHost2 webHost;
        if (!(webHost := hostManager.getWebHost(domain))) {
            if (webAppInfo.active) {
                console.print ($"No host for {domain} but domain is marked as active. Fixing it.");
                using (val tx = dbConnection.createTransaction()) {
                    tx.accounts.put(accountInfo.id, accountInfo.updateWebAppStatus(domain, False));
                }
            }
            return WebAppOperationResult.Conflict, $"The application is not running";
        }

        hostManager.removeWebHost(webHost);
        webHost.close();

        using (val tx = dbConnection.createTransaction()) {
            tx.accounts.put(accountInfo.id, accountInfo.updateWebAppStatus(domain, False));
        }

        return WebAppOperationResult.OK, "";
    }

    @Override
    void removeWebApp(String accountName, String appName) {
        using (val tx = dbConnection.createTransaction()) {
            if (
                AccountInfo accountInfo := getAccount(accountName),
                WebAppInfo webAppInfo := accountInfo.webApps.get(appName)
                ) {

                tx.accounts.put(accountInfo.id, accountInfo.removeWebApp(appName));
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