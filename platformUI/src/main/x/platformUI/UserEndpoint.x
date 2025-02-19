import sec.Credential;
import sec.Principal;
import sec.Realm;

import web.*;
import web.responses.SimpleResponse;
import web.security.DigestCredential;

import DigestCredential.Hash;
import DigestCredential.sha512_256;

/**
 * Dedicated service for user management.
 */
@WebService("/user")
service UserEndpoint
        extends CoreService {
    /**
     * Return the SimpleResponse with the current user id or `NoContent`.
     */
    @Get("id")
    SimpleResponse getUserId() {
        return new SimpleResponse(OK, Text, bytes=session?.principal?.name.utf8())
             : new SimpleResponse(NoContent);
    }

    /**
     * Log in the specified user.
     */
    @Post("login{/userName}")
    @HttpsRequired
    SimpleResponse login(SessionData session, String userName, @BodyParam String password = "") {
        Realm realm = ControllerConfig.realm;

        if (Principal principal := realm.findPrincipal(DigestCredential.Scheme, userName.quoted()),
                      principal.calcStatus(realm) == Active) {

            Hash hash = DigestCredential.passwordHash(userName, realm.name, password, sha512_256);
            for (Credential credential : principal.credentials) {
                if (credential.is(DigestCredential) &&
                        credential.matches(userName, hash)) {
                    session.authenticate(principal);
                    return getUserId();
                }
            }
        }
        return new SimpleResponse(Unauthorized);
    }

    /**
     * Get the current account name.
     */
    @Get("account")
    @LoginRequired
    @SessionRequired
    String account() = accountName;

    /**
     * Log out the current user.
     */
    @Post("logout")
    @HttpsRequired
    HttpStatus signOut(SessionData session) {
        session.deauthenticate();
        return HttpStatus.NoContent;
    }
}