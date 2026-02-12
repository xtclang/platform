import json.*;
import sec.*;
import web.*;
import web.responses.SimpleResponse;

/**
 * New API for user management.
 */
@WebService("/api/v1/auth")
@HttpsRequired
@SessionRequired
service User {

    UserEndpoint delegate.get() {
        private @Lazy UserEndpoint delegate_.calc() = new UserEndpoint();

        UserEndpoint delegate = delegate_;
        delegate.request = this.request;
        return delegate;
    }

    // TODO: very temporary; remove
    @Options("{/path*}")
    @SessionOptional
    HttpStatus preflight() = OK;

    @Get("/user")
    @LoginRequired
    JsonObject getUser() {
        Principal principal = session?.principal? : assert;
        // TODO: this is temporary; for single-user version only
        return [
            "id"         = $"user-{principal.principalId}",
            "email"      = "admin@xqiz.it",
            "name"       = principal.name,
            "screenName" = principal.name,
            "verified"   = True,
            "role"       = "admin",
            "provider"   = "email",
        ];
    }

    @Post("/login")
    JsonObject|HttpStatus login(@BodyParam JsonObject loginInfo) {
        String email    = loginInfo["email"]   .as(String);
        String password = loginInfo["password"].as(String);

        // TODO: login using the email
        String userName;
        if (Int at := email.indexOf('@')) {
            userName = email[0..<at];
        } else {
            userName = email;
        }
        SimpleResponse response = delegate.login(userName, password);
        return response.status == OK
                ? getUser()
                : Unauthorized;
    }

    @Post("/logout")
    HttpStatus signOut() = delegate.signOut();
}
