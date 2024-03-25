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

    @Command("injections", "Get a list of injection that may need to be supplied")
    String injections(String deploymentName) {
       return Gateway.sendRequest(GET, $"/webapp/injections/{deploymentName}");
    }

    @Command("get-injection", "Retrieve an injection value")
    String getInjectionValue(String deploymentName, String injectionName) {
       String value = Gateway.sendRequest(GET, $"/webapp/injections/{deploymentName}/{injectionName}");
       return value == "" ? "<empty>" : value;
    }

    @Command("set-injection", "Specify an injection value")
    void setInjectionValue(String deploymentName, String injectionName, String value) {
       Gateway.sendRequest(PUT, $"/webapp/injections/{deploymentName}/{injectionName}", value, Text);
    }

    @Command("remove-injection", "Remove an injection value")
    void removeInjectionValue(String deploymentName, String injectionName) {
       Gateway.sendRequest(DELETE, $"/webapp/injections/{deploymentName}/{injectionName}");
    }

    @Command("start", "Start an app")
    String start(String deploymentName) {
       return Gateway.sendRequest(POST, $"/webapp/start/{deploymentName}");
    }

    @Command("app-log", "Show the app log file")
    String showLog(String deploymentName) {
       return Gateway.sendRequest(GET, $"/webapp/appLog/{deploymentName}");
    }

    @Command("unregister", "Unregister an app")
    String unregister(String deploymentName) {
       return Gateway.sendRequest(DELETE, $"/webapp/unregister/{deploymentName}");
    }
}
