import json.Printer;

/**
 * Repository related commands.
 */
class Repositories {

    @Command("repos", "List of the repositories")
    void list() {
        Doc|HttpStatus result = GithubGateway.sendRequest(GET, "orgs", "/repos");
        if (result.is(Doc)) {
            assert Doc[] repos := result.is(Doc[]);
            for (Doc repo : repos) {
                assert repo.is(Map<String, Doc>);

                githubCLI.print($|name={repo.getOrNull("name")}
                                 |descr={repo.getOrNull("description")}
                                 |
                                 );
            }
        } else {
            githubCLI.print($"Request failed: {result}");
        }
    }
}
