/**
 * The platform command line tool.
 */
module platformCLI.xqiz.it
        incorporates TerminalApp("Platform command line tool", "Platform CLI>") {
    package cli import cli.xtclang.org;
    package net import net.xtclang.org;
    package web import web.xtclang.org;

    import cli.Command;
    import cli.Desc;
    import cli.TerminalApp;

    import net.Uri;
    import web.*;

    @Inject Console console;

    @Override
    void run(String[] args) {
        console.print("*** Platform Command Line Tool");
        console.print($"Enter platform server URL [{PlatformURL}]:", True);

        Uri platformUri = new Uri(readLine(PlatformURL));

        String? scheme = platformUri.scheme;
        if (scheme == Null) {
            platformUri = platformUri.with(scheme = "https");
        } else {
            assert scheme.toLowercase() == "https"
                as "This tool can only operate over SSL";
        }

        Gateway.platformUri = platformUri;
        Gateway.resetClient();
        while (True) {
            Gateway.collectCredentials();
            String account = Gateway.sendRequest(GET, "/user/account");
            if (account != "") {
                console.print($"Connected to the account {account}");
                break;
            }
        }
        super([]);
    }

    static service Gateway {
        @Unassigned Client client;
        @Unassigned Uri    platformUri;

        private String? name;
        private String? password;

        void resetClient() {
            client = new HttpClient();
        }

        void collectCredentials() {
            console.print("User name [admin]: ", suppressNewline=True);
            name = readLine("admin");

            setPassword(readPassword());
        }

        String readPassword() {
            String password;
            do {
                console.print("Password: ", suppressNewline=True);
                password = console.readLine(suppressEcho=True);
                // TODO REMOVE
                if (password == "") {
                    password = "password";
                }

            } while (password == "");

            return password;
        }

        void setPassword(String password) {
            this.password = password;
        }

        RequestOut createRequest(HttpMethod method, String path,
                                 Object? content=Null, MediaType? mediaType=Null) {
            import web.codecs.Base64Format;
            import web.codecs.Utf8Codec;

            String authorization = $|Bearer \
                                    |{Base64Format.Instance.encode(
                                    |   Utf8Codec.encode(credentials()))}
                                    ;
            RequestOut request =
                client.createRequest(method, platformUri.with(path=path),
                                            content, mediaType);
            request.header.put(Header.Authorization, authorization);
            return request;
        }

        (String, HttpStatus) send(RequestOut request) {
            ResponseIn response = client.send(request);
            HttpStatus status   = response.status;
            if (status == OK) {
                assert Body body ?= response.body;
                return body.bytes.unpackUtf8(), status;
            } else {
                platformCLI.print(response.toString());
                return "", status;
            }
        }

        String sendRequest(HttpMethod method, String path) {
            return send(createRequest(method, path));
        }

        String credentials() = $"{name}:{password}";
    }

    // ----- helpers -------------------------------------------------------------------------------

    static String readLine(String defaultValue = "") {
        @Inject Console console;

        String value = console.readLine().trim();
        return value == "" ? defaultValue : value;
    }

    static String PlatformURL = "https://xtc-platform.localhost.xqiz.it";
}