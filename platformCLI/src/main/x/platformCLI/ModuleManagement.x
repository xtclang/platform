class ModuleManagement {

    @Command("modules", "Show all modules")
    String modules() = platformCLI.get("/module/all");

    @Command("upload", "Upload a module at the specified path")
    String upload(String path) {
        @Inject Directory curDir;
        @Inject Directory rootDir;

        String uri = "/module/upload?redeploy=false";
        if (path.startsWith("/")) {
            if (File file := rootDir.findFile(path.substring(1))) {
                return platformCLI.upload(uri, file);
            }
        } else if (File file := curDir.findFile(path)) {
            return platformCLI.upload(uri, file);
        }
        return $"<Unknown file: {path.quoted()}>";
    }
}
