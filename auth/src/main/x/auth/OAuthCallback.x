import sec.Principal;

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
service OAuthCallback(DBRealm realm)
        implements Duplicable {

    @Override
    construct(OAuthCallback that) {
        this.realm = that.realm;
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
            return redirectTo(request.url.with(path=redirect, query=Delete));
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
        @Inject Console console;
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
