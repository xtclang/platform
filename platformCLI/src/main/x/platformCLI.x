/**
 * The platform command line tool.
 *
 * Note: unlike the standard "webcli" usage, we incorporate `TerminalApp` rather than annotate to
 *       override the "run" method.
 */
module platformCLI.xqiz.it
        incorporates TerminalApp("Platform Command Line Tool", "Platform CLI>") {

    package convert import convert.xtclang.org;
    package web     import web.xtclang.org;
    package webauth import webauth.xtclang.org;
    package webcli  import webcli.xtclang.org;

    package platformAuth import auth.xqiz.it;

    import webcli.*;

    @Inject Console console;

    @Override
    void run(String[] args) =
        Gateway.run(this, args, auth=Password, forceTls=True, init=showAccount);

    void showAccount() {
        import web.HttpStatus;

        (String name, String password) = Gateway.getPassword();
        while (True) {
            (_, HttpStatus status) = Gateway.sendRequest(POST, $"/user/login/{name}", password, Text);

            if (status == OK) {
                String account = Gateway.sendRequest(GET, "/user/account");
                print($"Connected to the account {account}");
                break;
            }

            print($"Failed to connect: {status}");
            (name, password) = Gateway.getPassword(force=True);
        }
    }
}