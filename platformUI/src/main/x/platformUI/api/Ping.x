import json.*;
import web.*;

/**
 * CORS policy test.
 */
@WebService("/api/v1/ping")
service Ping {

    @Get("")
    JsonObject pingAll() {
        return ["hello"="everyone"];
    }

    @Get("/hello")
    JsonObject pingHello() {
        return ["hello"="world", "user"=session?.principal?.name:"none"];
    }

    @Get("/secure")
    @HttpsRequired
    JsonObject pingSecure() {
        return ["hello"="secure", "user"=session?.principal?.name:"none"];
    }

    @Get("/session")
    @HttpsRequired
    @SessionRequired
    JsonObject pingSession() {
        return ["hello"="session", "user"=session?.principal?.name:"none"];
    }
}
