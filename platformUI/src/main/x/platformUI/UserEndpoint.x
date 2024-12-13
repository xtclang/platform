import sec.Credential;
import sec.Principal;
import sec.Realm;

import web.*;
import web.responses.SimpleResponse;
import web.security.DigestCredential;

import DigestCredential.Hash;
import DigestCredential.sha512_256;


/*
 * Dedicated service for user management.
 */
@WebService("/user")
service UserEndpoint
        extends CoreService {
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
    SimpleResponse login(SessionData session, String userName, @BodyParam String password = "") {
        Realm realm = webApp.authenticator.realm;

        // the code below is a part of DigestAuthenticator.authenticate(); TODO: create a helper there
        if (Principal principal := realm.findPrincipal(DigestCredential.Scheme, userName.quoted())) {
            Authenticator.Status status = principal.calcStatus(realm) == Active ? Success : NotActive;

            Hash hash = DigestCredential.passwordHash(userName, realm.name, password, sha512_256);
            for (Credential credential : principal.credentials) {
                if (credential.scheme == DigestCredential.Scheme
                        && credential.is(DigestCredential)
                        && credential.isUser(userName)
                        && credential.active) {

                    if (credential.password_sha512_256 == hash) {
                        session.authenticate(principal);
                        return getUserId();
                    }
                }
            }
        }
        return new SimpleResponse(Unauthorized);
    }

    /*
     * Get the current account name.
     */
    @Get("account")
    @LoginRequired
    @SessionRequired
    String account() {
        return accountName;
    }

    /*
     * Change the password.
     */
    @Put("password")
    @LoginRequired
    void setPassword(Session session, @BodyParam String password) {
        import common.model.UserInfo;

        Realm realm = webApp.authenticator.realm;

        String userName = session.principal?.name : assert;
        assert UserInfo userInfo := accountManager.getUser(userName);

        assert Principal principal := realm.findPrincipal(DigestCredential.Scheme, userName.quoted());
        TODO
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