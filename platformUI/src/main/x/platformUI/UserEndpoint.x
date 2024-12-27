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
        return new SimpleResponse(OK, Text, bytes=session?.principal?.name.utf8())
             : new SimpleResponse(NoContent);
    }

    /*
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

    /*
     * Get the current account name.
     */
    @Get("account")
    @LoginRequired
    @SessionRequired
    String account() = accountName;

    /*
     * Change the password.
     *
     * The client must append "Base64(oldPassword):Base64(newPassword)" as a message body.
     */
    @Put("password")
    @LoginRequired
    SimpleResponse setPassword(Session session, @BodyParam String passwords) {
        import common.model.UserInfo;
        import convert.formats.Base64Format;

        assert Int delim := passwords.indexOf(':');

        String b64Old = passwords[0 ..< delim];
        String b64New = passwords.substring(delim+1);

        String passwordOld = Base64Format.Instance.decode(b64Old).unpackUtf8();
        String passwordNew = Base64Format.Instance.decode(b64New).unpackUtf8();

        String userName = session.principal?.name : assert;
        Realm  realm    = ControllerConfig.realm;

        if (Principal principal := realm.findPrincipal(DigestCredential.Scheme, userName.quoted()),
                      principal.calcStatus(realm) == Active) {

            Hash hashOld = DigestCredential.passwordHash(userName, realm.name, passwordOld, sha512_256);
            Hash hashNew = DigestCredential.passwordHash(userName, realm.name, passwordNew, sha512_256);

            Credential[] credentials = principal.credentials;
            FindOld: for (Credential credential : credentials) {
                if (credential.is(DigestCredential) &&
                        credential.matches(userName, hashOld)) {
                    credentials = credentials.reify(Mutable);
                    credentials[FindOld.count] = credential.with(password_sha512_256=hashNew);
                    credentials = credentials.toArray(Constant, inPlace=True);
                    principal   = realm.updatePrincipal(principal.with(credentials=credentials));

                    session.authenticate(principal);
                    return new SimpleResponse(OK);
                }
            }
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