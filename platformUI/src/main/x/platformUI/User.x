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
service User
        extends CoreService {
    construct() {
        construct CoreService();

        realm = ControllerConfig.realm;
    }

    /**
     * The Realm used for authentication.
     */
    protected Realm realm;

    /*
     * Return the SimpleResponse with the current user id or `NoContent`.
     */
    @Get("id")
    SimpleResponse getUserId() {
        return new SimpleResponse(OK, bytes=session?.userId?.utf8())
             : new SimpleResponse(NoContent);
    }

    /*
     * Log in the specified user.
     */
    @Post("login/{userName}")
    @HttpsRequired
    SimpleResponse login(SessionData session, String userName, @BodyParam String password) {
        if (realm.authenticate(userName, password)) {
            session.authenticate(userName);
            Collection<String> accounts = accountManager.getAccounts(userName);

            // TODO choose an account this user was last associated with
            if (String accountName := accounts.any()) {
                session.accountName = accountName;
            }
            return getUserId();
        }
        return new SimpleResponse(Unauthorized);
    }

    /*
     * Log out the current user.
     */
    @Put("logout")
    @HttpsRequired
    HttpStatus signOut(SessionData session) {
        session.deauthenticate();
        session.accountName = Null;
        return HttpStatus.NoContent;
    }
}