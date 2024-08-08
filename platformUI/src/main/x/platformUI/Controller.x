import web.*;

@WebService("/host")
service Controller
        extends CoreService {

    @Post("debug")
    @LoginOptional // TODO: remove
    HttpStatus debug() {
        assert:debug;
        return HttpStatus.OK;
    }

    @Post("shutdown")
    @LoginOptional // TODO: TEMPORARY: only the admin can shutdown the host
    HttpStatus shutdown() {
        @Inject Console console;
        console.print($"Info: Shutting down...");

        @Inject Clock clock;
        if (!hostManager.shutdown()) {
            // wait a second (TODO: repeat a couple of times)
            clock.schedule(Second, () ->
                {
                hostManager.shutdown(True);
                httpServer.close();
                });
            return HttpStatus.Processing;
        }
        accountManager.shutdown();

        // respond first; terminate the server an eon later
        clock.schedule(Duration.ofMillis(10), httpServer.&close);
        return HttpStatus.OK;
    }
}