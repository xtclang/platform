class ModuleManagement {

    @Command("modules", "Show all modules")
    String modules() = platformCLI.get("/module/all");
}
