class HostManagement {

    @Command("config", "Get the current configuration values")
    String getConfig() = platformCLI.get("/host/config");

    @Command("set-active", "Set the active application threshold value")
    void setActiveThreshold(Int value) = platformCLI.post($"/host/config/active/{value}");

    // TEMPORARY
    @Command("debug", "Bring the debugger")
    void debug(String target = "server") {
        if (target.equals("local")) {
            assert:debug;
            String msg = "Debugging the CLI tool itself!";
        } else {
            platformCLI.post("/host/debug");
        }
    }

    @Command("shutdown", "Shutdown the platform server")
    void shutdown() {
        try {
            platformCLI.post("/host/shutdown");
        } catch (Exception e) {}
    }
}
