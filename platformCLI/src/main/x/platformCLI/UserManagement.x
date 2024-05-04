class UserManagement {

    // ----- commands --------------------------------------------------------------------------

    @Command("acc", "Get the account")
    String account() {
       return Gateway.sendRequest(GET, "/user/account");
    }

    @Command("password", "Change the credentials and the session cookies")
    void changePassword() {
        String newPassword;
        do {
            @Inject Console console;

            newPassword = console.readLine("New password:", suppressEcho=True);
            if (newPassword == "") {
                platformCLI.print("Cancelled");
                return;
            }

        } while (newPassword != console.readLine("Confirm password:", suppressEcho=True));

        RequestOut request = Gateway.createRequest(PUT, "/user/password", newPassword, Text);
        (_, HttpStatus status) = Gateway.send(request);

        if (status == OK) {
            Gateway.setPassword(newPassword);
            Gateway.resetClient();
        }
    }

    // TEMPORARY
    @Command("debug", "Bring the debugger")
    void debug(String target = "server") {
        if (target.equals("local")) {
            assert:debug;
            String msg = "Debugging the CLI tool itself!";
        } else {
            Gateway.sendRequest(POST, "/host/debug");
        }
    }

    @Command("shutdown", "Shutdown the platform server")
    void shutdown() {
        try {
            Gateway.sendRequest(POST, "/host/shutdown");
        } catch (Exception e) {}
    }
}
