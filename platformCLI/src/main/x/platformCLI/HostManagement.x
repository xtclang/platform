class HostManagement {

    @Command("config", "Get the current configuration values")
    String getConfig() {
        return Gateway.sendRequest(GET, "/host/config");
    }

    @Command("set-active", "Set the active application threshold value")
    void setActiveThreshold(Int value) {
        Gateway.sendRequest(POST, $"/host/config/active/{value}");
    }

    // TEMPORARY
    @Command("debug", "Bring the debugger")
    void debug(String target = "server") {
        if (target.equals("local")) {
            assert:debug;
            String msg = "Debugging the CLI tool itself!";
        } else {
            Gateway.sendRequest(POST, "/host/debug");
        }
    }

    @Command("shutdown", "Shutdown the platform server")
    void shutdown() {
        try {
            Gateway.sendRequest(POST, "/host/shutdown");
        } catch (Exception e) {}
    }
}
