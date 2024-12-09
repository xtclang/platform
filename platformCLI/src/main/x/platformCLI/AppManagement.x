class AppManagement {

    // ---- generic app end-points -----------------------------------------------------------------

    @Command("apps", "Show all registered apps")
    String allApps() {
        String jsonString = platformCLI.get("/apps/deployments");
        try {
            import json.Doc;
            import json.JsonObject;
            import json.Parser;
            import json.Printer;

            Doc doc = new Parser(jsonString.toReader()).parseDoc();
            assert doc.is(JsonObject);
            StringBuffer buf = new StringBuffer();
            for ((String deployment, Doc info) : doc) {
                if (!info.is(JsonObject)) {
                    continue;
                }

                assert Doc moduleName := info.get("moduleName");
                buf.append($"{deployment}: {moduleName}");
                if (Doc hostName := info.get("hostName")) {
                    buf.append(", hostName=").append(hostName);
                }
                Boolean started = info.getOrDefault("autoStart", False).as(Boolean);
                if (started) {
                    Boolean active = info.getOrDefault("active", False).as(Boolean);
                    buf.append(active ? ", active" : ", inactive");
                } else {
                    buf.append(", not started");
                }
               buf.add('\n');
            }
            return buf.toString();
        } catch (Exception e) {
            return jsonString;
        }
    }

    @Command("app", "Show the specified app")
    String appInfo(String deploymentName) = platformCLI.get($"/apps/deployments/{deploymentName}");

    @Command("unregister", "Delete the deployment")
    String unregister(String deploymentName, Boolean force = False) {
        if (!force) {
            String ack = console.readLine(
                    "Are you sure? All the application data will be deleted. [yes/no]: ");
            if (!ack.startsWith("y")) {
                return "";
            }
        }
        return platformCLI.delete($"/apps/deployments/{deploymentName}");
    }

    @Command("stats", "Get the deployment stats")
    String getStats(String deploymentName) =
        platformCLI.get($"/apps/stats/{deploymentName}");

    @Command("injections", "Get a list of injection that may need to be supplied")
    String injections(String deploymentName) =
        platformCLI.get($"/apps/injections/{deploymentName}");

    @Command("get-injection", "Retrieve an injection value")
    String getInjectionValue(String deploymentName, String injectionName, String injectionType = "") {
        String value = platformCLI.get(
                        $"/apps/injections/{deploymentName}/{injectionName}/{injectionType}");
        return value == "" ? "<empty>" : value;
    }

    @Command("set-injection", "Specify an injection value")
    void setInjectionValue(String deploymentName, String injectionName, String value,
                           String injectionType = "") {
        platformCLI.put($"/apps/injections/{deploymentName}/{injectionName}/{injectionType}", value, Text);
    }

    @Command("remove-injection", "Remove an injection value")
    void removeInjectionValue(String deploymentName, String injectionName,
                              String injectionType = "") {
        platformCLI.delete($"/apps/injections/{deploymentName}/{injectionName}/{injectionType}");
    }

    @Command("start", "Start an app")
    String start(String deploymentName) =
        platformCLI.post($"/apps/start/{deploymentName}");

    @Command("stop", "Stop the app")
    String stop(String deploymentName) =
        platformCLI.post($"/apps/stop/{deploymentName}");

    @Command("logs", "Show the app log file")
    String showLog(String deploymentName, String dbName = "") =
        platformCLI.get($"/apps/logs/{deploymentName}/{dbName}");

    // ---- web app end-points ---------------------------------------------------------------------

    @Command("register-web", "Register a web app")
    String registerWebApp(String deploymentName, String moduleName, String provider = "self") =
        platformCLI.put($"/apps/web/{deploymentName}/{moduleName}/{provider}");

    @Command("renew", "Renew the certificate for a web app")
    String renewWebApp(String deploymentName, String provider = "self") =
        platformCLI.post($"/apps/renew/{deploymentName}/{provider}");

    @Command("mark-shared", "Mark the specified DB deployment as shared")
    String markShared(String deploymentName, String dbDeploymentName) =
        platformCLI.put($"/apps/shared/{deploymentName}/{dbDeploymentName}");

    @Command("unmark-shared", "Unmark the specified DB deployment as shared")
    String unmarkShared(String deploymentName, String dbDeploymentName) =
        platformCLI.delete($"/apps/shared/{deploymentName}/{dbDeploymentName}");

    // ---- db app end-points ----------------------------------------------------------------------

    @Command("register-db", "Register a db app")
    String registerDbApp(String deploymentName, String moduleName) =
        platformCLI.put($"/apps/db/{deploymentName}/{moduleName}");
}
