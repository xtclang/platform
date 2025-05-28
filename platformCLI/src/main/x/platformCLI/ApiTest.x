class ApiTest {

    // ----- auth ----------------------------------------------------------------------------------

    @Command("api-get-user", "API V1: get current user")
    String getUser() = platformCLI.get("/api/v1/auth/user");

    // ----- modules -------------------------------------------------------------------------------

    @Command("api-all-modules", "API V1: list modules")
    String getModules() = platformCLI.get("/api/v1/modules");

    @Command("api-get-module", "API V1: get module by name")
    String getModule(String moduleName) = platformCLI.get($"/api/v1/modules/{moduleName}");

    @Command("api-upload-module", "API V1: Upload a module at the specified path")
    String upload(String path) {
        @Inject Directory curDir;
        @Inject Directory rootDir;

        String uri = "/api/v1/modules?redeploy=false";
        if (path.startsWith("/")) {
            if (File file := rootDir.findFile(path.substring(1))) {
                return platformCLI.upload(uri, file);
            }
        } else if (File file := curDir.findFile(path)) {
            return platformCLI.upload(uri, file);
        }
        return $"<Unknown file: {path.quoted()}>";
    }

    // ----- projects ------------------------------------------------------------------------------

    @Command("api-all-projects", "API V1: list projects (deployments)")
    String getProjects() = platformCLI.get("/api/v1/projects");

    @Command("api-get-project", "API V1: get project by name")
    String getProject(String projectName) = platformCLI.get($"/api/v1/projects/{projectName}");

    @Command("api-projects-by-module", "API V1: projects that use the specified module")
    String findProjects(String moduleName) = platformCLI.get($"/api/v1/projects?usesModule={moduleName}");
}