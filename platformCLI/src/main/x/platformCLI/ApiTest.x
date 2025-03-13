class ApiTest {

    // ----- auth ----------------------------------------------------------------------------------

    @Command("api-get-user", "API V1: get current user")
    String getUser() = platformCLI.get("/api/v1/auth/user");

    // ----- modules -------------------------------------------------------------------------------

    @Command("api-get-modules", "API V1: list modules")
    String getModules() = platformCLI.get("/api/v1/modules");

    // ----- projects ------------------------------------------------------------------------------

    @Command("api-get-projects", "API V1: list projects (deployments)")
    String getProjects() = platformCLI.get("/api/v1/projects");
}