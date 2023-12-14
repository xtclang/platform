import common.WebHost;

import web.HttpStatus;

import xenia.HttpHandler;
import xenia.HttpServer;
import xenia.HttpServer.Handler;
import xenia.HttpServer.RequestContext;

/**
 * The main request router.
 */
service Router(HttpServer httpServer, String baseDomain)
        implements Handler {

    /**
     * The catalog of known routes. At the moment, the routes are the "Host" names as known by the
     * user agent.
     */
    private Map<String, Handler> routes = new HashMap();

    /**
     * Add a route.
     */
    void addRoute(String route, Handler handler) {
        routes.put(route, handler);
    }

    /**
     * Remove a route.
     */
    void removeRoute(String route) {
        routes.remove(route);
    }


    // ----- Handler API ---------------------------------------------------------------------------

    @Override
    void handle(RequestContext context, String uri, String methodName, Boolean tls) {

        String? host = httpServer.getClientHostName(context);
        if (host != Null, Handler handler := routes.get(host)) {
            handler.handle^(context, uri, methodName, tls);
            return;
        }

        // TODO: REMOVE
        @Inject Console console;
        console.print($"Unknown route: {host}");

        httpServer.send(context, HttpStatus.NoResponse.code, [], [], []);
    }


    // ----- lifecycle -----------------------------------------------------------------------------

    /**
     * Shutdown thw Router.
     *
     * @param force  if True, force the shutdown; otherwise attempt to perform a grateful one
     *
     * @return True iff the shutdown has succeeded; False if it was re-scheduled
     */
    Boolean shutdown(Boolean force=False) {
        Boolean reschedule = False;
        for (Handler handler : routes.values) {
            if (handler.is(WebHost)) {
                reschedule |= !handler.deactivate(True);
            }
            else if (handler.is(HttpHandler)) {
                reschedule |= !handler.shutdown(force);
            }
        }

        if (reschedule && !force) {
            // wait a second (TODO: repeat a couple of times)
            @Inject Timer timer;
            timer.schedule(Second, httpServer.close);
            return False;
        }
        httpServer.close();
        return True;
    }


    // ----- Object API ----------------------------------------------------------------------------

    @Override
    String toString() {
        return $"Router@{baseDomain}";
    }
}
