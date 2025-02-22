import json.JsonObject;

import sec.Principal;

import web.requests.SimpleRequest;

import webauth.AuthSchema;
import webauth.DBRealm;

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
@Abstract service OAuthProvider(String provider) {

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

    @Inject Console console;

    /**
     * Initiate the authentication flow by asking the authorization provider for an authorization
     * grant.
     */
    ResponseOut initiateAuth(RequestIn request, String redirectPath, String callbackPath) {
        if (++attempts > 8) {
            console.print($"Error: Authentication request rejected: too many attempts");
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
            console.print($"Error: Cross-site forgery detected");
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
        try (val _ = new Timeout(requestTimeout)) {
            accessResponse = httpClient.send(accessRequest);
        } catch (Exception e) {
            console.print($|Error: Authentication request with "{provider}" has timed out
                         );
            return True, abortAuthentication(request);
        }

        if (JsonObject messageIn := accessResponse.to(JsonObject)) {
            if (String token := messageIn.getOrDefault("access_token", Null).is(String)) {
                accessToken = messageIn.get("access_token")?.is(String)? : assert;
                attempts = 0;
                return False;
            } else {
                console.print($|Error: Authorization request with "{provider}" has failed: \
                               |"login" info is missing in the response
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
        if (accessToken == Null) {
            return False;
        }
        RequestOut userRequest = new SimpleRequest(httpClient, GET, new Uri(userIdUrl),
                                    accepts=new AcceptList(Json));
        userRequest.header[Header.Authorization] = $"Bearer {accessToken}";

        ResponseIn userResponse;
        try (val _ = new Timeout(requestTimeout)) {
            userResponse = httpClient.send(userRequest);
        } catch (Exception e) {
            console.print($|Error: Authorization request with "{provider}" has timed out
                         );
            return True, abortAuthentication(request);
        }

        if (JsonObject messageIn := userResponse.to(JsonObject)) {
            if ((String userName, String email) := extractUserInfo(messageIn)) {

                // TODO: temporary; create OAuthCredential; consult with the Realm
                Principal principal = new Principal(0, userName);
                request.session?.authenticate(principal, [], trustLevel=Highest) : assert;

                return True, redirectTo(request.url.with(path=redirectPath, query=Delete));
            } else {
                // there is no user info in the request
                return True, abortAuthentication(request);
            }
        } else {
            // the request failed; try to get a new access token
            accessToken  = Null;
            requestState = Null;
            console.print($"Error: Authorization request failed: {userResponse}");
            return False;
        }
    }

    @Abstract
    conditional (String name, String email) extractUserInfo(JsonObject userInfo);

    /**
     * Abort the authentication process by redirecting the client (user agent) to the "root" URL.
     */
    ResponseOut abortAuthentication(RequestIn request) {
        accessToken  = Null;
        requestState = Null;
        return redirectTo(request.url.with(path="/", query=Delete));
    }

    // ----- concrete implementations --------------------------------------------------------------

    static service Github
        extends OAuthProvider("github") {

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
     */
    static service Google
        extends OAuthProvider("google") {

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

        @Override
        conditional (String, String) extractUserInfo(JsonObject userInfo) {
            if (String name  := userInfo.getOrDefault("name",  Null).is(String),
                String email := userInfo.getOrDefault("email", Null).is(String)) {
                return True, name, email;
            }
            return False;
        }
    }
}