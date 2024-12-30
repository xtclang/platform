class UserManagement
    extends webauth.mgmt.UserManagement{

    @Command("acc", "Get the account")
    String account() = platformCLI.get("/user/account");
}