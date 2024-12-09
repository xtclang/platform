class UserManagement {

    @Command("acc", "Get the account")
    String account() = platformCLI.get("/user/account");

    @Command("password", "Change the credentials and the session cookies")
    void changePassword() {
        String password;
        do {
            @Inject Console console;

            password = console.readLine("New password:", suppressEcho=True);
            if (password == "") {
                platformCLI.print("Cancelled");
                return;
            }

        } while (password != console.readLine("Confirm password:", suppressEcho=True));

        import web.HttpStatus;
        import web.RequestOut;

        RequestOut request = Gateway.createRequest(PUT, "/user/password", password, Text);
        (_, HttpStatus status) = Gateway.send(request);

        if (status == OK) {
            Gateway.resetClient(uriString=Gateway.serverUri(), authString=$"admin:{password}");
            platformCLI.showAccount();
        }
    }
}