class ModuleManagement {

    @Command("modules", "Show all modules")
    String modules() {
       return Gateway.sendRequest(GET, "/module/all");
    }
}
