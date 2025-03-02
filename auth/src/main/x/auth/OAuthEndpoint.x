import sec.Credential;
import sec.Principal;

import web.security.Authenticator;

import webauth.DBRealm;
import webauth.OAuthCredential;

/**
 * The `OAuthEndpoint` is a [WebService] that serves as the
 * (client redirection endpoint)[https://www.rfc-editor.org/rfc/rfc6749#section-3.1.2] as well
 * as an [Authenticator] for [OAuthCredential]s.
 *
 * TODO: instead of redirecting to "/' upon failure, consider passing an "error" redirect as well
 *       and having a "last error" endpoint to supply that information
 */
@WebService("/.well-known/oauth")
@HttpsRequired
service OAuthEndpoint(DBRealm realm, Authenticator authenticator)
        implements Authenticator, WebService.ExtrasAware
        delegates Authenticator - Duplicable(authenticator) {

    /**
     * The web app console (backed by the console.log in the deployment root directory)
     */
    @Inject Console console;

    @Override
    construct(OAuthEndpoint that) {
        this.realm         = that.realm;
        this.authenticator = that.authenticator;
    }

    // ----- ExtrasAware interface -----------------------------------------------------------------

    @Override
    (Duplicable+WebService)[] extras.get() = [this, new UserEndpoint(realm)];

    // ----- Authenticator interface ---------------------------------------------------------------

    @Override
    Attempt[] authenticate(RequestIn request) {
        if (SessionData     session   := request.session.is(SessionData),
            OAuthCredential oauthCred := session.credential.is(OAuthCredential)) {

            String        provider     = oauthCred.provider;
            OAuthProvider providerImpl = session.getProvider(provider, realm);
            try {
                if ((Principal? principal, Credential? credential) :=
                            providerImpl.requestUserInfo(request),
                        principal != Null && credential != Null) {
                    return [new Attempt(principal, Success, Null, credential)];
                }

                // TODO: use refresh protocol
            } catch (TimedOut e) {
                console.print($"Error: Authentication request to {provider} has timed out");
                return [new Attempt(Null, KnownNoData)];
            }

            String      callback = $"/.well-known/oauth/callback/{provider}";
            String      redirect = request.url.path ?: "/";
            ResponseOut response = providerImpl.requestAuthorization(request, redirect, callback);

            return [new Attempt(Null, InProgress, response)];
        }
        return authenticator.authenticate(request); // TODo GG: super(request) should work
    }

    // ----- "OAuth protocol" operations -----------------------------------------------------------

    /**
     * Login using OAuth with the specified provider (e.g. "github" or "google")
     */
    @Get("/login{/provider}{/redirect}")
    @Produces(Text)
    ResponseOut logIn(RequestIn request, SessionData session, String provider, String redirect) {
        if (!redirect.startsWith('/')) {
            redirect = "/" + redirect; // the path must be absolute
        }

        if (Principal principal ?= session.principal,
                      principal.calcStatus(realm) == Active) {
            // the session is already authenticated; redirect to the app page
            return redirectTo(request.url.with(path=redirect));
        }

        OAuthProvider providerImpl = session.getProvider(provider, realm);
        if (ResponseOut success := providerImpl.retrieveUser(request)) {
            return success;
        }

        // the access token has expired; get a new one
        // TODO: consider implementing a refresh protocol that some providers support
        String callback = $"/.well-known/oauth/callback/{provider}";
        return providerImpl.requestAuthorization(request, redirect, callback);
    }

    @Get("/callback{/provider}{?code,state}")
    @Produces(Text)
    ResponseOut callback(RequestIn request, SessionData session, String provider,
                         String code = "", String state = "") {
        OAuthProvider providerImpl = session.getProvider(provider, realm);
        if (ResponseOut failure := providerImpl.getAccessToken(request, code, state)) {
            return failure;
        }
        if (ResponseOut success := providerImpl.retrieveUser(request)) {
            return success;
        }
        // failure; abort the authentication
        return redirectTo(request.url.with(path="/", query=Delete));
    }

    @OnError
    ResponseOut handleErrors(RequestIn request, Exception|String|HttpStatus cause) {
        console.print($"Error: Authorization request has failed: {cause}");
        return redirectTo(request.url.with(path="/", query=Delete));
    }

    mixin SessionData
            into Session {
        /**
         * Get an [OAuthProvider] implementation for the specified provider name.
         */
        OAuthProvider getProvider(String provider, DBRealm realm) {
            if (providers.empty) {
                providers = new ListMap(); // mutable
            }
            return providers.computeIfAbsent(provider, () ->
                switch (provider) {
                case "amazon": new OAuthProvider.Amazon(realm);
                case "apple" : new OAuthProvider.Apple(realm);
                case "github": new OAuthProvider.Github(realm);
                case "google": new OAuthProvider.Google(realm);
                default:       new OAuthProvider.Unknown(provider, realm);
                });
        }

        /**
         * The map of the provider implementations.
         */
        Map<String, OAuthProvider> providers = [];
    }
}
