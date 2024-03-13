import ecstasy.mgmt.Container;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import web.*;
import web.http.FormDataFile;
import web.responses.SimpleResponse;

import web.security.Realm;

/*
 * Dedicated service for user management.
 */
@WebService("/user")
service UserEndpoint
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
     * Log in the specified user; choose an account and assign the corresponding role(s).
     */
    @Post("login/{userName}")
    @HttpsRequired
    SimpleResponse login(SessionData session, String userName, @BodyParam String password="") {
        if (realm.authenticate(userName, password)) {
            session.authenticate(userName);
            return getUserId();
        }
        return new SimpleResponse(Unauthorized);
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