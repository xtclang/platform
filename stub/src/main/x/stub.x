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
            String html = $./not-deployed.html;
            for ((String tag, String value) : tags) {
                html = html.replace(tag, value);
            }
            bytes = html.utf8();
        }

        /**
         * The "Unavailable" page content.
         */
        private Byte[] bytes;

        @Get("{path}")
        SimpleResponse getResource(String path) {
            return path == "/" || path == "" || path == "index.html"
                ? new SimpleResponse(OK, HTML, bytes)
                : unavailable();
        }

        @OnError
        ResponseOut onError(Session? session, RequestIn request,
                            (Exception|String|HttpStatus) cause) {
            return unavailable();
        }

        private SimpleResponse unavailable() = new SimpleResponse(ServiceUnavailable);
    }
}