/**
 * The challenge WebApp used to serve ACME challenge requests when a deployments have been
 * registered, but either not yet deployed or deactivated for whatever reason.
 */
@WebApp
module challenge.xqiz.it {
    package web import web.xtclang.org;

    import web.*;

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
            @Inject Console console;
            console.print($"### acme challenge: {path}"); // TODO REMOVE

            return super($".well-known/acme-challenge/{path}");
        }
    }
}