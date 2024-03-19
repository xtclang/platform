class WebAppManagement {

    // ----- commands --------------------------------------------------------------------------

    @Command("apps", "Show all web apps")
    String apps() {
       return Gateway.sendRequest(GET, "/webapp/status");
    }

    @Command("register", "Register an app")
    String register(String deploymentName, String moduleName) {
       return Gateway.sendRequest(POST, $"/webapp/register/{deploymentName}/{moduleName}");
    }

    @Command("start", "Start an app")
    String start(String deploymentName) {
       return Gateway.sendRequest(POST, $"/webapp/start/{deploymentName}");
    }

    @Command("unregister", "Unregister an app")
    String unregister(String deploymentName) {
       return Gateway.sendRequest(DELETE, $"/webapp/unregister/{deploymentName}");
    }
}
