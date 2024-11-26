import ecstasy.mgmt.Container;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import web.*;
import web.http.FormDataFile;
import web.responses.SimpleResponse;


/*
 * Dedicated service for user management.
 */
@WebService("/user")
service UserEndpoint
        extends CoreService {
    construct() {
        construct CoreService();

        realm = ControllerConfig.realm; // TODO: not needed; webApp.authenticator.realm
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
        return new SimpleResponse(OK, bytes=session?.principal?.name.utf8())
             : new SimpleResponse(NoContent);
    }

    /*
     * Log in the specified user.
     */
    @Post("login{/userName}")
    @HttpsRequired
    SimpleResponse login(SessionData session, String userName, @BodyParam String password="") {
        if (realm.authenticate(userName, password)) {
            session.authenticate(userName);
            return getUserId();
        }
        return new SimpleResponse(Unauthorized);
    }

    /*
     * Get the current account name.
     */
    @Get("account")
    @LoginRequired
    String account() {
        return accountName;
    }

    /*
     * Change the password.
     */
    @Put("password")
    @LoginRequired
    void setPassword(@BodyParam String password) {
        import common.model.UserInfo;

        String userId = session?.userId? : assert;
        assert UserInfo userInfo := accountManager.getUser(userId);

        Principal principal = realm.findPrincipal(DigestCredentials.Scheme, userId);
    }

    /*
     * Log out the current user.
     */
    @Post("logout")
    @HttpsRequired
    HttpStatus signOut(SessionData session) {
        session.deauthenticate();
        return HttpStatus.NoContent;
    }
}