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
        @Inject Timer timer;

        if (!hostManager.shutdown()) {
            // wait a second (TODO: repeat a couple of times)
            timer.schedule(Second, () ->
                {
                hostManager.shutdown(True);
                httpServer.close();
                });
            return HttpStatus.Processing;
        }
    accountManager.shutdown();

    // respond first; terminate the server an eon later
    timer.schedule(Duration.ofMillis(10), httpServer.&close);
    return HttpStatus.OK;
    }
}