/**
 * The platform command line tool.
 *
 * Note: unlike the standard "webcli" usage, we incorporate `TerminalApp` rather than annotate to
 *       override the "run" method.
 */
module platformCLI.xqiz.it
        incorporates TerminalApp("Platform Command Line Tool", "Platform CLI>") {
    package web     import web.xtclang.org;
    package webcli  import webcli.xtclang.org;

    import webcli.*;

    @Inject Console console;

    @Override
    void run(String[] args) =
        Gateway.run(this, args, auth=Password, forceTls=True, init=showAccount);

    void showAccount() {
        import web.HttpStatus;

        while (True) {
            (String account, HttpStatus status) = Gateway.sendRequest(GET, "/user/account");
            if (status == OK) {
                print($"Connected to the account {account}");
                break;
            }

            print($"Failed to connect: {status}");
            Gateway.resetClient(forceTls=True);
        }
    }
}