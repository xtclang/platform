import json.*;
import web.*;

@WebService("/host")
service Controller
        extends CoreService {

    @Get("config")
    JsonObject showConfig() {
        JsonObject config = json.newObject();
        config["activeThreshold"] = 0; // hostManager.activeAppThreshold.toIntLiteral();
        return config.makeImmutable();
    }

    @Post("config/active/{count}")
    void setActiveCount(Int count) {
        assert:bounds 0 <= count < 100;
        // hostManager.activeAppThreshold = count;
    }

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
        console.print("Info: Shutting down...");

        @Inject Clock clock;
        if (!hostManager.shutdown()) {
            // wait a second (TODO: repeat a couple of times)
            clock.schedule(Second, () ->
                {
                console.print("Info: Forcing shutdown");
                hostManager.shutdown(True);
                accountManager.shutdown();
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