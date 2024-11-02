/**
 * The platform command line tool.
 */
module platformCLI.xqiz.it
        incorporates TerminalApp("Platform command line tool", "Platform CLI>") {
    package cli     import cli.xtclang.org;
    package convert import convert.xtclang.org;
    package json    import json.xtclang.org;
    package net     import net.xtclang.org;
    package web     import web.xtclang.org;

    import cli.Command;
    import cli.Desc;
    import cli.TerminalApp;

    import json.Doc;
    import json.Parser;
    import json.Printer;

    import net.Uri;
    import web.*;

    @Inject Console console;

    @Override
    void run(String[] args) {
        console.print("*** Platform Command Line Tool");

        String uriString = args.size > 0
            ? args[0]
            : readLine($"Enter platform server URL [{PlatformURL}]: ", PlatformURL);

        Uri     platformUri = new Uri(uriString);
        String? scheme      = platformUri.scheme;
        if (scheme == Null) {
            platformUri = new Uri($"https://{uriString}");
        } else {
            assert scheme.toLowercase() == "https" as "This tool can only operate over SSL";
        }
        console.print($"Connecting to \"{platformUri}\"");

        Gateway.platformUri = platformUri;
        Gateway.resetClient();
        while (True) {
            if (args.size > 2) {
                Gateway.setCredentials(args[1], args[2]);
                args = [];
            } else {
                Gateway.collectCredentials();
            }
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

        void setCredentials(String name, String password) {
            this.name     = name;
            this.password = password;
        }

        void collectCredentials() {
            name = readLine("User name [admin]: ", "admin");

            setPassword(readPassword());
        }

        String readPassword() {
            String password;
            do {
                password = console.readLine("Password:", suppressEcho=True);
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
            import convert.formats.Base64Format;
            import convert.codecs.Utf8Codec;

            String authorization = $|Bearer \
                                    |{Base64Format.Instance.encode(
                                    |   Utf8Codec.encode(credentials()))}
                                    ;
            RequestOut request =
                client.createRequest(method, platformUri.with(path=path), content, mediaType);
            request.header[Header.Authorization] = authorization;
            return request;
        }

        (String, HttpStatus) send(RequestOut request) {
            ResponseIn response = client.send(request);
            HttpStatus status   = response.status;
            if (status == OK) {
                assert Body body ?= response.body;
                Byte[] bytes = body.bytes;
                if (bytes.size == 0) {
                    return "", status;
                }

                switch (body.mediaType) {
                case Text:
                    return bytes.unpackUtf8(), status;
                case Json:
                    String jsonString = bytes.unpackUtf8();
                    Doc    doc        = new Parser(jsonString.toReader()).parseDoc();
                    return Printer.PRETTY.render(doc), status;
                default:
                    return $"<Unsupported media type: {body.mediaType}>", status;
                }
            } else {
                platformCLI.print(response.toString());
                return "", status;
            }
        }

        String sendRequest(HttpMethod method, String path,
                           Object? content=Null, MediaType? mediaType=Null) {
            return send(createRequest(method, path, content, mediaType));
        }

        String credentials() = $"{name}:{password}";
    }

    // ----- helpers -------------------------------------------------------------------------------

    static String readLine(String prompt, String defaultValue = "") {
        @Inject Console console;

        String value = console.readLine(prompt).trim();
        return value == "" ? defaultValue : value;
    }

    static String PlatformURL = "https://xtc-platform.localhost.xqiz.it";
}