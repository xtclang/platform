/**
 * The stub WebApp used to serve requests when a deployments have been registered, but either not
 * yet deployed or deactivated for whatever reason.
 */
@WebApp
module stub.xqiz.it {
    package web import web.xtclang.org;

    import web.*;
    import web.responses.SimpleResponse;

    /**
     * "The application is temporary not available" service.
     */
    @WebService("/")
    service Unavailable {
        construct(Map<String, String> tags) {
            bytes = applyTags($./not-deployed.html, tags).utf8();
        }

        /**
         * The "Unavailable" page content.
         */
        private Byte[] bytes;

        @Get("{/path?}")
        SimpleResponse getResource(String path) {
            return isLandingPath(path)
                ? new SimpleResponse(OK, HTML, bytes)
                : unavailable();
        }

        @OnError
        ResponseOut onError(RequestIn request, (Exception|String|HttpStatus) cause) {
            return unavailable();
        }

        private SimpleResponse unavailable() = new SimpleResponse(ServiceUnavailable);

        // ----- pure helpers (static: callable and unit-testable without a running service) -------

        /**
         * Does this request path address the stub's landing page (the site root or its
         * `index.html`), as opposed to some other resource that should yield a "service
         * unavailable" response?
         */
        static Boolean isLandingPath(String path) = path == "" || path == "index.html";

        /**
         * Produce the page content by substituting each `tag` placeholder found in `template`
         * with its replacement value.
         */
        static String applyTags(String template, Map<String, String> tags) =
                tags.reduce(template, (html, entry) -> html.replace(entry.key, entry.value));
    }
}
