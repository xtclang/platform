class WebAppManagement {

    // ---- generic app end-points -----------------------------------------------------------------

    @Command("apps", "Show all registered apps")
    String allApps() {
        return Gateway.sendRequest(GET, "/apps/deployments");
    }

    @Command("app", "Show the specified app")
    String appInfo(String deploymentName) {
        return Gateway.sendRequest(GET, $"/apps/deployments/{deploymentName}");
    }

    @Command("unregister", "Delete the deployment")
    String unregister(String deploymentName, Boolean force = False) {
        if (!force) {
            String ack = readLine(
                    "Are you sure? All the application data will be deleted. [yes/no]: ", "no");
            if (!ack.startsWith("y")) {
                return "";
            }
        }
        return Gateway.sendRequest(DELETE, $"/apps/deployments/{deploymentName}");
    }

    @Command("stats", "Get the deployment stats")
    String getStats(String deploymentName) {
        return Gateway.sendRequest(GET, $"/apps/stats/{deploymentName}");
    }

    @Command("injections", "Get a list of injection that may need to be supplied")
    String injections(String deploymentName) {
        return Gateway.sendRequest(GET, $"/apps/injections/{deploymentName}");
    }

    @Command("get-injection", "Retrieve an injection value")
    String getInjectionValue(String deploymentName, String injectionName,
                             String injectionType = "") {
        String value = Gateway.sendRequest(GET,
            $"/apps/injections/{deploymentName}/{injectionName}/{injectionType}");
        return value == "" ? "<empty>" : value;
    }

    @Command("set-injection", "Specify an injection value")
    void setInjectionValue(String deploymentName, String injectionName, String value,
                           String injectionType = "") {
        Gateway.sendRequest(PUT,
            $"/apps/injections/{deploymentName}/{injectionName}/{injectionType}", value, Text);
    }

    @Command("remove-injection", "Remove an injection value")
    void removeInjectionValue(String deploymentName, String injectionName,
                              String injectionType = "") {
        Gateway.sendRequest(DELETE,
            $"/apps/injections/{deploymentName}/{injectionName}/{injectionType}");
    }

    @Command("start", "Start an app")
    String start(String deploymentName) {
        return Gateway.sendRequest(POST, $"/apps/start/{deploymentName}");
    }

    @Command("stop", "Stop the app")
    String stop(String deploymentName) {
        return Gateway.sendRequest(POST, $"/apps/stop/{deploymentName}");
    }

    @Command("logs", "Show the app log file")
    String showLog(String deploymentName, String dbName = "") {
        return Gateway.sendRequest(GET, $"/apps/logs/{deploymentName}/{dbName}");
    }

    // ---- web app end-points ---------------------------------------------------------------------

    @Command("register-web", "Register a web app")
    String registerWebApp(String deploymentName, String moduleName, String provider = "self") {
        return Gateway.sendRequest(PUT, $"/apps/web/{deploymentName}/{moduleName}/{provider}");
    }

    @Command("renew", "Renew the certificate for a web app")
    String renewWebApp(String deploymentName, String provider = "self") {
        return Gateway.sendRequest(POST, $"/apps/renew/{deploymentName}/{provider}");
    }

    @Command("mark-shared", "Mark the specified DB deployment as shared")
    String markShared(String deploymentName, String dbDeploymentName) {
        return Gateway.sendRequest(PUT,
            $"/apps/shared/{deploymentName}/{dbDeploymentName}");
    }

    @Command("unmark-shared", "Unmark the specified DB deployment as shared")
    String unmarkShared(String deploymentName, String dbDeploymentName) {
        return Gateway.sendRequest(DELETE,
            $"/apps/shared/{deploymentName}/{dbDeploymentName}");
    }

    // ---- db app end-points ----------------------------------------------------------------------

    @Command("register-db", "Register a db app")
    String registerDbApp(String deploymentName, String moduleName) {
        return Gateway.sendRequest(PUT, $"/apps/db/{deploymentName}/{moduleName}");
    }
}
