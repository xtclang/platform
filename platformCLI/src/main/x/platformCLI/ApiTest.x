import json.*;

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

    @Command("api-add-project", "API V1: add project")
    String addProject(String projectName, String moduleName, String? injections = Null) {
        JsonObjectBuilder project = json.objectBuilder();
        project.addAll([
            "name"   = projectName,
            "module" = moduleName,
        ]);
        if (injections != Null && !injections.empty) {
            Map<String, String> values = injections.splitMap(); // e.g. "org=PetStore,state=MA"

            JsonArrayBuilder injectionValues = json.arrayBuilder();
            for ((String key, String value) : values) {
                injectionValues.addObject([key=value]);
            }
            project.add("injections", injectionValues.build());
        }
        return platformCLI.post($"/api/v1/projects", project.build(), Json);
    }

    @Command("api-update-project", "API V1: update project")
    String updateProject(String projectName, String? injections = Null, String? provider = Null) {
        JsonObjectBuilder project = json.objectBuilder();

        if (injections != Null && !injections.empty) {
            Map<String, String> values = injections.splitMap(); // e.g. "org=PetStore,state=MA"

            JsonArrayBuilder injectionValues = json.arrayBuilder();
            for ((String key, String value) : values) {
                injectionValues.addObject([key=value]);
            }
            project.add("injections", injectionValues.build());
        }
        if (provider != Null && !provider.empty) {
            project.add("certProvider", provider);
        }
        return platformCLI.patch($"/api/v1/projects/{projectName}", project.build(), Json);
    }

    @Command("api-projects-by-module", "API V1: projects that use the specified module")
    String findProjects(String moduleName) = platformCLI.get($"/api/v1/projects?usesModule={moduleName}");

    @Command("api-start", "API V1: start the app")
    String start(String projectName) = platformCLI.post($"/api/v1/projects/{projectName}/start");

    @Command("api-stop", "API V1: stop the app")
    String stop(String projectName)  = platformCLI.post($"/api/v1/projects/{projectName}/stop");
}