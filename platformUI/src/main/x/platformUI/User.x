import ecstasy.mgmt.Container;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;

import web.*;
import web.http.FormDataFile;
import web.responses.SimpleResponse;

import web.security.Realm;

/*
 * Dedicated service for user management.
 */
@WebService("/user")
service User {
    construct() {
        accountManager = ControllerConfig.accountManager;
        hostManager    = ControllerConfig.hostManager;
        realm          = ControllerConfig.realm;
    }

    /**
     * The account manager.
     */
    private AccountManager accountManager;

    /**
     * The host manager.
     */
    private HostManager hostManager;

    /**
     * The Realm used for authentication.
     */
    private Realm realm;

    /**
     * The current account name.
     */
    String accountName.get() {
        return session?.userId? : "";
    }

    /*
     * Returns the SimpleResponse with the current user id or `NoContent`.
     */
    @Get("id")
    SimpleResponse getUserId() {
        return accountName == ""
            ? new SimpleResponse(NoContent)
            : new SimpleResponse(OK, Null, accountName.utf8());
    }

    /*
     * Log in the specified user.
     */
    @Get("login/{user}/{password}")
    @HttpsRequired
    SimpleResponse login(Session session, String user, String password) {
        if (realm.authenticate(user, password)) {
            session.authenticate(user);
            return getUserId();
        }
        return new SimpleResponse(Unauthorized);
    }

    /*
     * Logs out the current user
     */
    @Put("logout")
    @HttpsRequired
    HttpStatus signOut() {
        session?.deauthenticate();
        return HttpStatus.NoContent;
    }
}