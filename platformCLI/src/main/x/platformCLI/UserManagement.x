class UserManagement
    extends platformAuth.UserManagement {

    @Command("acc", "Get the account")
    String account() = platformCLI.get("/user/account");
}