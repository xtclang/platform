import sec.Entitlement;
import sec.Principal;

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

    private AccountManager accountManager;

    String accountName;

    @Override
    void sessionAuthenticated(Principal? principal, Entitlement[] entitlements) {
        if (principal != Null) {
            String                  user     = principal.name;
            Collection<AccountInfo> accounts = accountManager.getAccounts(user);

            // TODO choose an account this user was last associated with
            if (AccountInfo account := accounts.any()) {
                accountName = account.name;

                assert accountManager.getUser(user);
            }
        }
        super(principal, entitlements);
    }

    @Override
    void sessionDeauthenticated(Principal? principal, Entitlement[] entitlements) {
        accountName = "";

        super(principal, entitlements);
    }
}
