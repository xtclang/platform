class UserManagement {

    @Command("acc", "Get the account")
    String account() = platformCLI.get("/user/account");

    @Command("password", "Change the credentials and the session cookies")
    void changePassword(String oldPassword = "", String newPassword = "") {
        if (oldPassword.empty || newPassword.empty) {
            do {
                @Inject Console console;

                oldPassword = console.readLine("Old password:", suppressEcho=True);
                if (oldPassword == "") {
                    platformCLI.print("Cancelled");
                    return;
                }
                newPassword = console.readLine("New password:", suppressEcho=True);
                if (newPassword == "") {
                    platformCLI.print("Cancelled");
                    return;
                }

            } while (newPassword != console.readLine("Confirm new password:", suppressEcho=True));
        }

        import convert.formats.Base64Format;
        import web.HttpStatus;
        import web.RequestOut;

        String b64Old = Base64Format.Instance.encode(oldPassword.utf8());
        String b64New = Base64Format.Instance.encode(newPassword.utf8());

        RequestOut request = Gateway.createRequest(PUT, "/user/password", $"{b64Old}:{b64New}", Text);
        (_, HttpStatus status) = Gateway.send(request);

        if (status == OK) {
            Gateway.resetClient(uriString=Gateway.serverUri(), authString=$"admin:{newPassword}");
            platformCLI.showAccount();
        } else {
            platformCLI.print($"Failed to reset the password: status");
        }
    }
}