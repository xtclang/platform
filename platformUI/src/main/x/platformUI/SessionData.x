import common.model.UserInfo;
import common.model.UserRole;

import web.Session;

/**
 * Session mixin that is automatically incorporated into a Session implementation.
 */
mixin SessionData
        into Session {
    construct() {
        accountManager = ControllerConfig.accountManager;
        accountName    = "";
    }

    @Unassigned
    private AccountManager accountManager;

    String accountName;

    @Override
    void sessionAuthenticated(String user) {
        Collection<AccountInfo> accounts = accountManager.getAccounts(user);

        // TODO choose an account this user was last associated with or present a choice back
        if (AccountInfo account := accounts.any()) {
            accountName = account.name;

            assert UserInfo userInfo := accountManager.getUser(user);
            if (UserRole userRole := account.users.get(userInfo.id)) {
                roles = [userRole.name]; // TODO: allow multiple roles
            }
        }
        super(user);
    }

    @Override
    void sessionDeauthenticated(String user) {
        accountName = "";

        super(user);
    }
}
