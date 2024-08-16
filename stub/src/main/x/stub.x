/**
 * The stub WebApp used to serve requests when a deployments have been registered, but either not
 * yet deployed or deactivated for whatever reason.
 */
@WebApp
module stub.xqiz.it {
    package web import web.xtclang.org;

    import web.*;
    import web.responses.SimpleResponse;

    @Inject Console console;

    /**
     * "The application is temporary not available" service.
     */
    @WebService("/")
    service Unavailable {
        construct(Map<String, String> tags = []) {
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

    /**
     * The WebService for ACME protocol requests from "Let's Encrypt".
     */
    @WebService("/.well-known/acme-challenge")
    service AcmeChallenge
            incorporates StaticContent {

        construct(Directory acmeChallengeDir) {
            construct StaticContent(path, acmeChallengeDir, mediaType=Text);
        }

        // ----- Handler -------------------------------------------------------------------------------

        @Override
        @Get("{path}")
//        @SessionOptional
        conditional ResponseOut getResource(String path) {
            console.print($"### challenge: {path}"); // TODO REMOVE

            return super($".well-known/acme-challenge/{path}");
        }
    }
}