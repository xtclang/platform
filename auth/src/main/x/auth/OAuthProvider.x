import json.JsonObject;

import sec.Credential;
import sec.Principal;

import web.requests.SimpleRequest;

import webauth.AuthSchema;
import webauth.DBRealm;
import webauth.OAuthCredential;

/**
 * OAuthProvider is an implementation of the basic OAuth 2.0 protocol.
 *
 * Note: The `clientId` and `clientSecret` values must be configured during the web application
 * registration with the hosting platform.
 *
 * @param provider  the provider name
 *
 * @see [The OAuth 2.0 Authorization Framework](https://www.rfc-editor.org/rfc/rfc6749)
 */
@Abstract service OAuthProvider(String provider, DBRealm realm) {

    /**
     * The HTTP client that is used to sent REST requests to the authorization server.
     */
    @Inject("client") Client httpClient;

    /**
     * The Url that is used to start the OAuth 2.0 protocol, asking the authorization server for
     * an authorization grant. This step is usually implemented via a redirect.
     *
     * @see https://www.rfc-editor.org/rfc/rfc6749#section-3.1
     */
    @RO String authorizationUrl;

    /**
     * The desired grant type.
     *
     * @see https://www.rfc-editor.org/rfc/rfc6749#section-3.1.1
     */
     @RO String responseType.get() = "code";

    /**
     * A space-delimited list of scopes that identify the resources that the provider could access
     * on the user's behalf. These values inform the consent screen that authorization server
     * displays to the user.
     *
     * @see https://www.rfc-editor.org/rfc/rfc6749#section-3.3
     */
     @RO String authorizationScope;

    /**
     * A unique string value that the provider uses to maintain state between the authorization
     * request and the authorization server's response.
     *
     * Strictly speaking this property is unnecessary since the xenia web dispatcher automatically
     * provides the defence against cross-site request forgery attacks, but this creates an
     * additional security barrier.
     *
     * @see https://www.rfc-editor.org/rfc/rfc6749#section-4.2.1
     */
    String? requestState;

    /**
     * The Url that is used to ask the authorization server for an exchange of the authorization
     * grant to an access token.
     */
    @RO String accessUrl;

    /**
     * The Url that is used to ask the authorization server for a user identity.
     */
    @RO String userIdUrl;

    /**
     * The timeout value that limits the period of time to receive a response from the authorization
     * server.
     */
    Duration requestTimeout = Duration.ofSeconds(5);

    /**
     * The access token to use for getting user info from the resource server.
     */
    String? accessToken;

    /**
     * The application redirect path to be used upon successful authorization.
     */
    String? redirectPath;

    /**
     * The callback URL to use in the OAuth protocol exchange.
     */
    String? callbackUrl;

    /**
     * The authentication attempt count.
     */
    Int attempts;

    /**
     * The web app console (backed by the console.log in the deployment root directory)
     */
    @Inject Console console;

    /**
     * Initiate the authentication flow by asking the authorization provider for an authorization
     * grant.
     */
    ResponseOut requestAuthorization(RequestIn request, String redirectPath, String callbackPath) {
        if (++attempts > 8) {
            console.print("Error: Authentication request rejected: too many attempts");
            return new SimpleResponse(TooManyRequests);
        }

        @Inject(opts=provider) String clientId;
        @Inject(opts=provider) String clientSecret;

        if (!&clientId.assigned || !&clientSecret.assigned) {
            return new SimpleResponse(Conflict,
                    $|Unspecified injections: "clientId" and "clientSecret" for "{provider}" \
                     |provider
                     );
        }

        console.print($"Info: Requesting authorization from {provider}");

        // store off the application redirect path and create a request state
        @Inject Random random;
        this.redirectPath = redirectPath;
        this.requestState = random.uint128().toString();
        this.callbackUrl  = request.url.with(path=callbackPath, query=Delete).toString();

        String redirectUrl =
                $|{authorizationUrl}\
                 |?client_id={clientId}\
                 |&response_type={responseType}\
                 |&scope={authorizationScope}\
                 |&state={requestState}\
                 |&redirect_uri={callbackUrl}
                 ;

        return redirectTo(redirectUrl, TemporaryRedirect);
    }

    /**
     * Using the received grant code, retrieve an access token.
     *
     * @return True iff the access token could not be retrieved
     * @return (conditional) the response to send back to the client (user agent)
     */
    conditional ResponseOut getAccessToken(RequestIn request, String grantCode, String requestState) {
        if (requestState != this.requestState) {
            console.print("Error: Cross-site forgery detected");
            return True, abortAuthentication(request);
        }
        @Inject(opts=provider) String clientId;
        @Inject(opts=provider) String clientSecret;

        // Note: some authorization servers simply ignore "grant_type" attribute
        String requestBody = $|client_id={clientId}\
                              |&client_secret={clientSecret}\
                              |&code={grantCode}\
                              |&grant_type=authorization_code\
                              |&redirect_uri={callbackUrl}
                              ;
        RequestOut accessRequest = new SimpleRequest(httpClient, POST, new Uri(accessUrl),
                requestBody, mediaType=FormURL, accepts=new AcceptList(Json));

        ResponseIn accessResponse;
        using (new Timeout(requestTimeout)) {
            accessResponse = httpClient.send(accessRequest);
        }

        if (JsonObject messageIn := accessResponse.to(JsonObject)) {
            if (accessToken := messageIn.getOrDefault("access_token", Null).is(String)) {
                attempts = 0;
                return False;
            } else {
                console.print($|Error: Authorization request with {provider} has failed; the \
                               |"access_token" is missing in the response
                             );
            }
        } else {
            // TODO: extract more detailed information about the failure reason from the response
            console.print($"Error: Authentication request failed: {accessResponse}");
        }

        // the request failed
        return True, abortAuthentication(request);
    }

    /**
     * Retrieve the user identity info from the authentication server. If the user information is
     * been successfully retrieved, the method returns the original url to redirect the user agent
     * to. Otherwise, it's a failure of the user request, which may indicate an access toke expiry.
     *
     * @return True iff the user agent needs to be redirected; False iff the access token is missing
     *              or has expired
     * @return (conditional) the response to send back to the client (user agent)
     */
    conditional ResponseOut retrieveUser(RequestIn request) {
        if ((Principal? principal, Credential? credential) := requestUserInfo(request)) {
            if (principal == Null || credential == Null) {
                // there is no user info in the request
                return True, abortAuthentication(request);
            }
            request.session?.authenticate(principal, credential, [], trustLevel=Highest) : assert;

            return True, redirectTo(request.url.with(path=redirectPath, query=Delete));
        } else {
            // there is no access token, or it has expired; try to get a new access token
            return False;
        }
    }

    /**
     * Request the identity info from the authentication server.
     *
     * @return True iff the there was a valid (not expired) access token to use for a request to the
     *              provider
     * @return (conditional) the `principal` and `credential` extracted from the provider response;
     *          `principal` could be `Null` if the necessary information was missing in the response,
     *          `credential` could be `Null` if the corresponding `Credential` has expired
     */
    conditional (Principal? principal, Credential? credential) requestUserInfo(RequestIn request) {
        if (accessToken == Null) {
            return False;
        }
        RequestOut userRequest = new SimpleRequest(httpClient, GET, new Uri(userIdUrl),
                                    accepts=new AcceptList(Json));
        userRequest.header[Header.Authorization] = $"Bearer {accessToken}";

        ResponseIn userResponse;
        using (new Timeout(requestTimeout)) {
            userResponse = httpClient.send(userRequest);
        }

        if (JsonObject messageIn := userResponse.to(JsonObject)) {
            if ((String userName, String email) := extractUserInfo(messageIn)) {

                Credential credential = new OAuthCredential(provider, userName, email);
                Principal  principal;
                using (realm.db.connection.createTransaction()) {
                    if (principal := realm.findPrincipal(credential)) {
                        if (Credential match := principal.credentials.any(cred ->
                                cred.is(OAuthCredential) && cred.provider == provider)) {
                            switch (Credential.Status status = match.calcStatus()) {
                            case Revoked, Suspended, Expired:
                                console.print($"Error: Credential for {email} at {provider} is {status}");
                                return True, principal, Null;
                            }
                        } else {
                            // even though we found the Principal for the locator (e.g. email),
                            // it used a different provider; add this one to the Principal
                            principal = principal.with(credentials=principal.credentials+credential);
                            realm.updatePrincipal(principal);
                        }
                    } else {
                        // create a new Principal with OAuthCredential
                        principal = new Principal(0, email, credentials=[credential]);
                        principal = realm.createPrincipal(principal);
                    }
                }
                return True, principal, credential;
            } else {
                // there is no user info in the request
                console.print($"Error: User info is missing: {messageIn}");
                return True, Null, Null;
            }
        } else {
            // the request failed; try to get a new access token
            accessToken  = Null;
            requestState = Null;
            console.print($"Error: Authorization request failed: {userResponse}");
            return False;
        }
    }

    /**
     * Extract the user name and email from the "user profile" Json object.
     */
    conditional (String name, String email) extractUserInfo(JsonObject userInfo) {
        if (String name  := userInfo.getOrDefault("name",  Null).is(String),
            String email := userInfo.getOrDefault("email", Null).is(String)) {
            return True, name, email;
        }
        return False;
    }

    /**
     * Abort the authentication process by redirecting the client (user agent) to the "root" URL.
     */
    ResponseOut abortAuthentication(RequestIn request) {
        accessToken  = Null;
        requestState = Null;
        return redirectTo(request.url.with(path="/", query=Delete));
    }

    // ----- concrete implementations --------------------------------------------------------------

    /**
     * REVIEW: do we need to implement refresh token protocol?
     *
     * @see https://developer.amazon.com/docs/login-with-amazon/web-docs.html
     */
    static service Amazon(DBRealm realm)
        extends OAuthProvider("amazon", realm) {

        @Override String authorizationUrl = "https://www.amazon.com/ap/oa";
        @Override String accessUrl        = "https://api.amazon.com/auth/o2/token";
        @Override String userIdUrl        = "https://api.amazon.com/user/profile";

        /**
         * @see https://developer.amazon.com/docs/login-with-amazon/requesting-scopes-as-essential-voluntary.html
         */
        @Override String authorizationScope.get() = "profile";
    }

    /**
     * REVIEW: do we need to implement refresh token protocol?
     *
     * @see https://developer.apple.com/documentation/signinwithapplerestapi
     * https://developer.apple.com/documentation/rosterapi/validating-with-the-roster-api-test-scope
     */
    static service Apple(DBRealm realm)
        extends OAuthProvider("apple", realm) {

        @Override String authorizationUrl = "https://appleid.apple.com/auth/oauth2/v2/authorize";
        @Override String accessUrl        = "https://appleid.apple.com/auth/oauth2/v2/token";
        @Override String userIdUrl        = "https://api-school.apple.com/rosterapi/v1/users?limit=2";

        /**
         * @see https://developer.apple.com/documentation/accountorganizationaldatasharing/request-an-authorization
         */
        @Override String authorizationScope.get() = "edu.users.read";

        @Override
        conditional (String, String) extractUserInfo(JsonObject userInfo) {
            if (String firstName  := userInfo.getOrDefault("givenName", Null).is(String),
                String lastName   := userInfo.getOrDefault("familyName", Null).is(String),
                String email := userInfo.getOrDefault("email", Null).is(String)) {
                return True, $"{firstName} {lastName}", email;
            }
            return False;
        }
    }

    /**
     * @see https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps
     */
    static service Github(DBRealm realm)
        extends OAuthProvider("github", realm) {

        @Override String authorizationUrl = "https://github.com/login/oauth/authorize";
        @Override String accessUrl        = "https://github.com/login/oauth/access_token";
        @Override String userIdUrl        = "https://api.github.com/user";

        /**
         * @see https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps
         */
        @Override String authorizationScope.get() = "user";

        @Override
        conditional (String, String) extractUserInfo(JsonObject userInfo) {
            if (String name  := userInfo.getOrDefault("login", Null).is(String),
                String email := userInfo.getOrDefault("email", Null).is(String)) {
                return True, name, email;
            }
            return False;
        }
    }

    /**
     * REVIEW: do we need to implement refresh token protocol?
     *
     * @see https://developers.google.com/identity/protocols/oauth2/web-server?hl=en
     */
    static service Google(DBRealm realm)
        extends OAuthProvider("google", realm) {

        @Override String authorizationUrl = "https://accounts.google.com/o/oauth2/v2/auth";
        @Override String accessUrl        = "https://oauth2.googleapis.com/token";
        @Override String userIdUrl        = "https://www.googleapis.com/oauth2/v2/userinfo";

        /**
         * @see https://developers.google.com/identity/protocols/oauth2/scopes#people
         */
        @Override String authorizationScope.get() =
            \|https://www.googleapis.com/auth/userinfo.profile \
             |https://www.googleapis.com/auth/userinfo.email
            ;
    }

    static service Unknown(String provider, DBRealm realm)
            extends OAuthProvider(provider, realm) {

        @Override
        conditional ResponseOut retrieveUser(RequestIn request) {
            console.print($"Error: Unknown provider: {provider}");
            return True, abortAuthentication(request);
        }
    }
}