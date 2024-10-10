/**
 * The Github interaction command line tool.
 *
 * Note: this library is exploratory and temporary. The plan is to integrate these commands into
 *       the Platform back end, driven by the Platform CLI or UI.
 */
module githubCLI.xqiz.it
        incorporates TerminalApp("Platform Github command line tool", "GH CLI>") {
    package cli  import cli.xtclang.org;
    package json import json.xtclang.org;
    package net  import net.xtclang.org;
    package web  import web.xtclang.org;

    import cli.Command;
    import cli.Desc;
    import cli.TerminalApp;

    import json.Doc;
    import json.Parser;

    import net.Uri;
    import web.*;

    @Inject Console console;

    @Override
    void run(String[] args) {
        console.print("*** Platform Github Command Line Tool");

        String githubOwner = readLine($"Enter Github owner [xtclang]: ", "xtclang");

        String token;
        if (!(token := findToken())) {
            do {
                token = console.readLine("Please enter the token: ", suppressEcho=True);
            } while (token == "");
        }

        GithubGateway.resetClient(githubOwner, token);

        super([]);
    }

    static service GithubGateway {
        private @Unassigned Client client;
        private @Unassigned String owner;
        private @Unassigned String token;

        void resetClient(String githubOwner, String token) {
            client     = new HttpClient();
            this.owner = githubOwner;
            this.token = token;
        }

        RequestOut createRequest(HttpMethod method, String group, String path, Object? content=Null) {
            Uri        uri     = new Uri($"https://api.github.com/{group}/{owner}{path}");
            RequestOut request = client.createRequest(method, uri, content);

            request.header.put(Header.Accept,        MediaType_GithubAPI);
            request.header.put(Header.Authorization, $"Bearer {token}");
            request.header.put(Header_GithubAPI,     "2022-11-28");
            return request;
        }

        (Doc|HttpStatus) send(RequestOut request) {
            ResponseIn response = client.send(request);
            HttpStatus status   = response.status;
            if (status == OK) {
                assert Body body ?= response.body;
                Byte[] bytes = body.bytes;
                if (bytes.size == 0) {
                    return status;
                }

                String jsonString = bytes.unpackUtf8();
                return new Parser(jsonString.toReader()).parseDoc().makeImmutable();
            } else {
                githubCLI.print(response.toString());
                return status;
            }
        }

        (Doc|HttpStatus) sendRequest(HttpMethod method, String group, String path, Object? content=Null) {
            return send(createRequest(method, group, path, content));
        }
    }

    // ----- helpers -------------------------------------------------------------------------------

    conditional String findToken() {
        @Inject Directory homeDir;
        if (File credentialsFile := homeDir.findFile(".git-credentials")) {
            for (String tokenString : credentialsFile.contents.unpackUtf8().split('\n')) {
                if (tokenString.empty) {
                    continue;
                }
                try {
                    // credential example: "https://joe:ghp_ABCDEFXYZ12345678@github.com"
                    Uri uri = new Uri(tokenString);
                    if (uri.host == "github.com",
                        String user ?= uri.user, Int tokenDelim := user.indexOf(':')) {

                        return True, user.substring(tokenDelim + 1);
                    }
                } catch (Exception e) {
                    console.print($"Failed to parse {credentialsFile} content: {e}");
                    return False;
                }
            }
        }
        return False;
    }

    String readLine(String prompt, String defaultValue = "") {
        String value = console.readLine(prompt).trim();
        return value == "" ? defaultValue : value;
    }

    static String MediaType_GithubAPI = "application/vnd.github+json";
    static String Header_GithubAPI    = "X-GitHub-Api-Version";
}