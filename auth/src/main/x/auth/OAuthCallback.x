/**
 * The `OAuthCallback` is a [WebService] that serves as the
 * (client redirection endpoint)[https://www.rfc-editor.org/rfc/rfc6749#section-3.1.2].
 *
 * TODO: instead of redirecting to "/' upon failure, consider passing an "error" redirect as well
 *       and having a "last error" endpoint to supply thqt information
 * TODO: implements Authenticator
 */
@WebService("/.well-known/oauth")
@HttpsRequired
service OAuthCallback { // (WebApp app, DBRealm realm)

    // ----- "OAuth protocol" operations -----------------------------------------------------------

    /**
     * Login using OAuth with the specified provider (e.g. github)
     */
    @Get("/login{/provider}{/redirect}")
    @Produces(Text)
    ResponseOut logIn(RequestIn request, SessionData session, String provider, String redirect) {
        if (!redirect.startsWith('/')) {
            redirect = "/" + redirect; // the path must be absolute
        }

        if (session.principal != Null) {
            // the session is already authenticated; redirect to the app page
            return redirectTo(request.url.with(path=redirect, query=Delete));
        }

        OAuthProvider providerImpl = session.getProvider(provider);
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
        OAuthProvider providerImpl = session.getProvider(provider);
        if (ResponseOut failure := providerImpl.getAccessToken(request, code, state)) {
            return failure;
        }
        if (ResponseOut success := providerImpl.retrieveUser(request)) {
            return success;
        }
        // failure; abort the authentication
        return redirectTo(request.url.with(path="/", query=Delete));
    }

    mixin SessionData
            into Session {
        /**
         * Get an [OAuthProvider] implementation for the specified provider name.
         */
        OAuthProvider getProvider(String provider) {
            if (providers.empty) {
                providers = new ListMap(); // mutable
            }
            return providers.computeIfAbsent(provider, () ->
                switch (provider) {
                case "amazon": new OAuthProvider.Amazon();
                case "apple" : new OAuthProvider.Apple();
                case "github": new OAuthProvider.Github();
                case "google": new OAuthProvider.Google();
                default:       new OAuthProvider.Unknown(provider);
                });
        }

        /**
         * The map of the provider implementations.
         */
        Map<String, OAuthProvider> providers = [];
    }
}
