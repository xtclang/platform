import sec.Credential;
import sec.Entitlement;
import sec.Principal;

import web.Session;

/**
 * Session annotation that is automatically incorporated into a Session implementation.
 */
annotation SessionData
        into Session {
    construct() {
        accountManager = ControllerConfig.accountManager;
        accountName    = "";
    }

    private AccountManager accountManager;

    String accountName;

    @Override
    void sessionAuthenticated(Principal? principal, Credential? credential,
                              Entitlement[] entitlements) {
        assert principal != Null;

        String                  user     = principal.name;
        Collection<AccountInfo> accounts = accountManager.getAccounts(user);

        // TODO choose an account this user was last associated with
        if (AccountInfo account := accounts.any()) {
            accountName = account.name;

            assert accountManager.getUser(user);
        }
        super(principal, credential, entitlements);
    }

    @Override
    void sessionDeauthenticated(Principal? principal, Credential? credential,
                                Entitlement[] entitlements) {
        accountName = "";

        super(principal, credential, entitlements);
    }
}
