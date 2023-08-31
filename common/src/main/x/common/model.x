package model {
    typedef UInt as AccountId;
    typedef UInt as UserId;

    enum UserRole {Admin, Developer, Observer}

    const AccountInfo(AccountId id, String name,
                      Map<String, ModuleInfo> modules = [],
                      Map<String, WebAppInfo> webApps = [],
                      Map<UserId, UserRole>   users   = []
                      ) {

        AccountInfo addOrUpdateModule(ModuleInfo info) {
            return new AccountInfo(id, name, modules.put(info.name, info), webApps, users);
        }

        AccountInfo removeModule(String moduleName) {
            return new AccountInfo(id, name, modules.remove(moduleName), webApps, users);
        }

        AccountInfo addOrUpdateUser(UserId userId, UserRole role) {
            return new AccountInfo(id, name, modules, webApps, users.put(userId, role));
        }

        AccountInfo removeUser(UserId userId) {
            return new AccountInfo(id, name, modules, webApps, users.remove(userId));
        }

        AccountInfo addOrUpdateWebApp(WebAppInfo info) {
            return new AccountInfo(id, name, modules, webApps.put(info.domain, info), users);
        }

        AccountInfo removeWebApp(String domain) {
            return new AccountInfo(id, name, modules, webApps.remove(domain), users);
        }
    }

    const AccountUser(UserId userId, AccountId accountId);

    const UserInfo(UserId id, String name, String email);

    const ModuleInfo(
        String            name,
        String            qualifiedName,
        Boolean           isResolved,
        Boolean           isWebModule,
        String[]          issues,
        DependentModule[] dependentModules
    );

    const DependentModule(String name, String qualifiedName, Boolean available);

    const WebAppInfo(
        String  moduleName,
        String  domain,
        String  hostName,
        String  bindAddr,
        UInt16  httpPort,
        UInt16  httpsPort,
        Boolean active) {

        assert() {
            // for now, the ports are consecutive and the http port is an even number
            assert httpPort % 2 == 0 && httpsPort == httpPort + 1;
        }

        WebAppInfo updateStatus(Boolean active) {
            return new WebAppInfo(moduleName, domain, hostName, bindAddr, httpPort, httpsPort, active);
        }
    }
}