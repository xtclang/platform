import json.JsonObject;
import json.JsonPointer;
import json.Printer;

/**
 * Repository related commands.
 */
class Repositories {

    String? repositoryName;
    Doc     repositoryInfo;

    String? branchName;
    Doc     branchInfo;

    @Command("repos", "List of the repositories")
    void listRepositories() {
        Doc|HttpStatus result = GithubGateway.sendRequest(GET, "orgs", "/repos");
        if (result.is(Doc)) {
            assert Doc[] repos := result.is(Doc[]);
            for (Doc repo : repos) {
                assert repo.is(JsonObject);

                console.print($|
                               |name={repo.getOrNull("name")}
                               |descr={repo.getOrNull("description")}
                             );
            }
        } else {
            console.print($"Request failed: {result}");
        }
    }

    @Command("set-repo", "Set a current repository")
    void setRepository(String repository) {
        Doc|HttpStatus result = GithubGateway.sendRequest(GET, "repos", $"/{repository}");
        if (result.is(Doc)) {
            assert result.is(JsonObject);
            repositoryName = repository;
            repositoryInfo = result;
            console.print(result.getOrNull("description"));
        } else {
            console.print($"Request failed: {result}");
        }
    }

    @Command("readme", "Get a repository README")
    void readme() {
        if (!checkRepository()) {
            return;
        }

        Doc|HttpStatus result =
                GithubGateway.sendRequest(GET, "repos", $"/{repositoryName}/readme");
        if (result.is(Doc)) {
            assert result.is(JsonObject),
                   Doc text := result.get("content"), text.is(String);

            import conv.formats.Base64Format;
            console.print(Base64Format.Instance.decode(text).unpackUtf8());
        } else {
            console.print($"Request failed: {result}");
        }
    }

    @Command("branches", "List of branches")
    void listBranches() {
        if (!checkRepository()) {
            return;
        }

        Doc|HttpStatus result =
                GithubGateway.sendRequest(GET, "repos", $"/{repositoryName}/branches");
        if (result.is(Doc)) {
            assert result.is(Doc[]);
            for (Doc branchInfo : result) {
                assert branchInfo.is(JsonObject);
                console.print(branchInfo.getOrNull("name"));
            }
        } else {
            console.print($"Request failed: {result}");
        }
    }

    @Command("set-branch", "Set a current branch")
    void setBranch(String branch = "master") {
        if (!checkRepository()) {
            return;
        }

        Doc|HttpStatus result =
                GithubGateway.sendRequest(GET, "repos", $"/{repositoryName}/branches/{branch}");
        if (result.is(Doc)) {
            assert result.is(JsonObject);
            branchName = branch;
            branchInfo = result;
            assert Doc lastCommitAuthor  := JsonPointer.from("commit/commit/author/name").get(result);
            assert Doc lastCommitMessage := JsonPointer.from("commit/commit/message").get(result);
            console.print($"{lastCommitAuthor}: {lastCommitMessage}");
        } else {
            console.print($"Request failed: {result}");
        }
    }

    private Boolean checkRepository() {
        if (repositoryName == Null) {
            console.print($"Error: Repository is not set (use 'set-repo' command)");
            return False;
        }
        return True;
    }
}
