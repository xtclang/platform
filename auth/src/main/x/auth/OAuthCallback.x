import convert.formats.Base64Format;

import json.JsonObject;

import sec.Principal;

import web.*;
import web.requests.SimpleRequest;
import web.responses.SimpleResponse;

import webauth.AuthSchema;
import webauth.DBRealm;

/**
 * The `OAuthCallback` is a [WebService] that serves as the
 * (client redirection endpoint)[https://www.rfc-editor.org/rfc/rfc6749#section-3.1.2].
 *
 * TODO: instead of redirecting to "/' upon failure, consider passing an "error" redirect as well
 *       and having a "last error" endpoint to supply thqt information
 */
@WebService("/.well-known/oauth")
@HttpsRequired
service OAuthCallback { // (WebApp app, DBRealm realm)

    /**
     * The client used to talk to the authorization server.
     */
    @Inject Client client;

    Duration providerTimeout = Duration.ofSeconds(5);

    // ----- "OAuth protocol" operations -----------------------------------------------------------

    /**
     * Login using OAuth with the specified provider (e.g. github)
     */
    @Get("/login{/provider}{/redirect}")
    @Produces(Text)
    ResponseOut logIn(RequestIn request, SessionData session, String provider, String redirect) {
        @Inject(opts=provider) String clientId;
        @Inject(opts=provider) String clientSecret;

        if (!redirect.startsWith('/')) {
            redirect = "/" + redirect; // the path must be absolute
        }

        HttpStatus redirectCode = PermanentRedirect;
        String     redirectUrl;

        while (True) {
            if (session.principal != Null) {
assert:debug;
                // the session is already authenticated; redirect to the app page
                redirectUrl = request.url.with(path=redirect).toString();
                session.redirect = Null;
                break;
            }

            if (String accessToken ?= session.accessToken) {
                // we already have the access token; go get the user info
                assert String userUrl := ProviderUser.get(provider);

                RequestOut userRequest = new SimpleRequest(client, GET, new Uri(userUrl),
                                            accepts=new AcceptList(Json));
                userRequest.header[Header.Authorization] = $"Bearer {accessToken}";

                ResponseIn userResponse;
                try (val _ = new Timeout(providerTimeout)) {
                    userResponse = client.send(userRequest);
                } catch (Exception e) {
                    @Inject Console console;
                    console.print($|Error: Authorization request with "{provider}" has timed out
                                 );
                    redirectUrl = request.url.with(path="/").toString();
                    break;
                }

                if (JsonObject messageIn := userResponse.to(JsonObject)) {

                    if (String userName := messageIn.getOrDefault("login", Null).is(String)) {
                        // set up the principal (existing or new)
                        String? userEmail = messageIn.get("email")?.is(String?)? : assert;

                        // TODO: temporary
                        Principal principal = new Principal(0, userName);
                        session.authenticate(principal, [], trustLevel=Highest);

                        // redirect to the app page
                        redirectUrl = request.url.with(path=redirect).toString();
                    } else {
                        session.accessToken = Null;
                        session.redirect    = Null;

                        @Inject Console console;
                        console.print($|Error: Authorization request with "{provider}" has failed: \
                                       |"login" info is missing in the response
                                     );
                        redirectUrl = request.url.with(path="/").toString();
                    }
                    break;
                } else {
                    // the request failed; try to get a new access token
                    session.accessToken = Null;

                    @Inject Console console;
                    console.print($"Error: Authorization request failed: {userResponse}");
                    // continue on re-acquiring the access token
                }
            }

            if (String sessionCode ?= session.accessCode) {
                // we have the session code; get the access token from the authorization server
                assert String accessUrl := ProviderAccess.get(provider) as
                        $"Unknown provider: {provider}";

                String requestBody = $|client_id={clientId}&\
                                      |client_secret={clientSecret}&\
                                      |code={sessionCode}
                                      ;
                RequestOut accessRequest = new SimpleRequest(client, POST, new Uri(accessUrl),
                        requestBody, mediaType=FormURL, accepts=new AcceptList(Json));

                ResponseIn accessResponse;
                try (val _ = new Timeout(providerTimeout)) {
                    accessResponse = client.send(accessRequest);
                } catch (Exception e) {
                    @Inject Console console;
                    console.print($|Error: Authentication request with "{provider}" has timed out
                                 );
                    redirectUrl = request.url.with(path="/").toString();
                    break;
                }

                if (JsonObject messageIn := accessResponse.to(JsonObject)) {
                    if (String token := messageIn.getOrDefault("access_token", Null).is(String)) {
                        session.accessToken = messageIn.get("access_token")?.is(String)? : assert;
                        session.attempts    = 0;
                        continue; // let's try to get the user data now
                    } else {
                        @Inject Console console;
                        console.print($|Error: Authorization request with "{provider}" has failed: \
                                       |"login" info is missing in the response
                                     );
                    }
                } else {
                    @Inject Console console;
                    console.print($"Error: Authentication request failed: {accessResponse}");
                }

                // the request failed; redirect to the "root" URL
                session.accessToken = Null;
                session.redirect    = Null;

                redirectUrl = request.url.with(path="/").toString();
                break;
            }

            // prevent an attack into this well-known endpoint by limiting a number of attempts for
            // a given user
            if (!&clientId.assigned || !&clientSecret.assigned) {
                return new SimpleResponse(Conflict,
                        $|Unspecified injections: "clientId" and "clientSecret" for "{provider}" \
                         |provider
                         );
            }

            if (++session.attempts > 8) {
                redirectUrl = request.url.with(path="/").toString();

                @Inject Console console;
                console.print($"Error: Authentication request rejected: too many attempts");
                return new SimpleResponse(TooManyRequests);
            }

            // we have no useful information; start by a redirect to the authorization server
            assert String authUrl := ProviderAuth.get(provider)
                    as "Unsupported OAuth provider {provider.quoted()}";

            // store off the application redirect path
            session.redirect = redirect;

            redirectUrl = request.url.with(path=
                $"/.well-known/oauth/callback/{provider}").toString();

            redirectCode = TemporaryRedirect;
            redirectUrl  = $|{authUrl}?\
                            |client_id={clientId}&\
                            |redirect_uri={redirectUrl}&\
                            |scope=user
                            ;
            break;
        }

        ResponseOut response = new SimpleResponse(redirectCode);
        response.header[Header.Location] = redirectUrl;
        return response;
    }

    @Get("/callback{/provider}")
    @Produces(Text)
    ResponseOut callback(RequestIn request, SessionData session, String provider,
                         @QueryParam String? code = Null) {
        session.accessCode = code;
        return logIn(request, session, provider, session.redirect ?: "/");
    }

    mixin SessionData
        into Session {

        /**
         * The access code to use for getting the access token from the authorization server.
         */
        String? accessCode;

        /**
         * The access token to use for getting user info from the authorization server.
         */
        String? accessToken;

        /**
         * The application redirect path.
         */
        String? redirect;

        /**
         * The authentication attempt count.
         */
        Int attempts;
    }

    static Map<String, String> ProviderAuth = [
        "github" = "https://github.com/login/oauth/authorize",
    ];

    static Map<String, String> ProviderAccess = [
        "github" = "https://github.com/login/oauth/access_token",
    ];

    static Map<String, String> ProviderUser = [
        "github" = "https://api.github.com/user",
    ];
}
