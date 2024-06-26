class WebAppManagement {

    // ----- commands --------------------------------------------------------------------------

    @Command("apps", "Show all web apps")
    String apps() {
        return Gateway.sendRequest(GET, "/webapp/status");
    }

    @Command("app", "Show the specified web app")
    String appInfo(String deploymentName) {
        return Gateway.sendRequest(GET, $"/webapp/status/{deploymentName}");
    }

    @Command("register", "Register an app")
    String register(String deploymentName, String moduleName, String provider = "self") {
        return Gateway.sendRequest(POST, $"/webapp/register/{deploymentName}/{moduleName}/{provider}");
    }

    @Command("injections", "Get a list of injection that may need to be supplied")
    String injections(String deploymentName) {
        return Gateway.sendRequest(GET, $"/webapp/injections/{deploymentName}");
    }

    @Command("get-injection", "Retrieve an injection value")
    String getInjectionValue(String deploymentName, String injectionName,
                             String injectionType = "") {
        String value = Gateway.sendRequest(GET,
                $"/webapp/injections/{deploymentName}/{injectionName}/{injectionType}");
        return value == "" ? "<empty>" : value;
    }

    @Command("set-injection", "Specify an injection value")
    void setInjectionValue(String deploymentName, String injectionName, String value,
                           String injectionType = "") {
        Gateway.sendRequest(PUT,
                $"/webapp/injections/{deploymentName}/{injectionName}/{injectionType}",
                value, Text);
    }

    @Command("remove-injection", "Remove an injection value")
    void removeInjectionValue(String deploymentName, String injectionName,
                              String injectionType = "") {
        Gateway.sendRequest(DELETE,
                $"/webapp/injections/{deploymentName}/{injectionName}/{injectionType}");
    }

    @Command("renew", "Renew the certificate")
    String renew(String deploymentName, String provider = "self") {
        return Gateway.sendRequest(POST, $"/webapp/renew/{deploymentName}/{provider}");
    }

    @Command("start", "Start an app")
    String start(String deploymentName) {
        return Gateway.sendRequest(POST, $"/webapp/start/{deploymentName}");
    }

    @Command("stop", "Stop the app")
    String stop(String deploymentName) {
        return Gateway.sendRequest(POST, $"/webapp/stop/{deploymentName}");
    }

    @Command("logs", "Show the app log file")
    String showLog(String deploymentName, String dbName = "") {
        return Gateway.sendRequest(GET, $"/webapp/logs/{deploymentName}/{dbName}");
    }

    @Command("unregister", "Unregister an app")
    String unregister(String deploymentName, Boolean force = False) {
        if (!force) {
            String ack = readLine(
                    "Are you sure? All the application data will be deleted. [yes/no]: ", "no");
            if (!ack.startsWith("y")) {
                return "";
            }
        }
        return Gateway.sendRequest(DELETE, $"/webapp/unregister/{deploymentName}");
    }
}
