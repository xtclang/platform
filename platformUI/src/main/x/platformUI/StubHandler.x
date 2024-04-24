import crypto.Decryptor;

import web.responses.SimpleResponse;

import xenia.HttpServer.Handler;
import xenia.HttpServer.RequestInfo;
import xenia.Http1Response;

/**
 * The handler for deployments that have been registered, but either not yet deployed or deactivated
 * for whatever reason.
 */
service StubHandler
        implements Handler {

    construct(File htmlFile, Map<String, String> tags) {
        String html = htmlFile.contents.unpackUtf8();
        for ((String tag, String value) : tags) {
            html = html.replace(tag, value);
        }
        this.html = html;
    }

    /**
     * The "stub" page content.
     */
    private String html;


    // ----- Handler -------------------------------------------------------------------------------

    @Override
    void handle(RequestInfo request) {

        (Int status, String[] names, String[] values, Byte[] body) =
            Http1Response.prepare(new SimpleResponse(OK, HTML, html.utf8()));

        request.respond(status, names, values, body);
    }
}
