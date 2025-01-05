/**
 * Web CLI commands for auth user management (see [AuthEndpoint] web service).
 */
import webcli.*;

class UserManagement {
    /**
     * The URI of the [AuthEndpoint] web service.
     */
    static String Path = "/.well-known/auth";

    // ----- "self management" operations ----------------------------------------------------------

    @Command("user", "Show current user")
    String getUser() = auth.get($"{Path}/profile");

    @Command("password", "Change password for current user")
    void changePassword(String oldPassword = "", String newPassword = "") {
        if (oldPassword.empty || newPassword.empty) {
            do {
                @Inject Console console;

                oldPassword = console.readLine("Old password:", suppressEcho=True);
                if (oldPassword == "") {
                    auth.print("Cancelled");
                    return;
                }
                newPassword = console.readLine("New password:", suppressEcho=True);
                if (newPassword == "") {
                    auth.print("Cancelled");
                    return;
                }

            } while (newPassword != console.readLine("Confirm new password:", suppressEcho=True));
        }

        import convert.formats.Base64Format;
        import web.HttpStatus;
        import web.RequestOut;

        String b64Old = Base64Format.Instance.encode(oldPassword.utf8());
        String b64New = Base64Format.Instance.encode(newPassword.utf8());

        RequestOut request = Gateway.createRequest(PATCH, $"{Path}/profile", $"{b64Old}:{b64New}", Text);
        (_, HttpStatus status) = Gateway.send(request);

        if (status == OK) {
            Gateway.resetClient(uriString=Gateway.serverUri(), authString=$"admin:{newPassword}");
        } else {
            auth.print($"Failed to reset the password: {status}");
        }
    }

    // ----- "user by id management" operations ----------------------------------------------------

    @Command("create-user", "Create user")
    String createUser(String name, String password) =
            auth.post($"{Path}/users/{name}", password, Text);

    @Command("show-user", "Get user by id")
    String showUser(Int userId) = auth.get($"{Path}/users/{userId}");

    @Command("find-user", "Find user by name")
    String findUser(String name) = auth.get($"{Path}/users?{name=}");

    @Command("reset-password", "Reset the password")
    String resetPassword(Int userId, String password) =
            auth.patch($"{Path}/users/{userId}/password", password, Text);

    @Command("add-user-permission", "Add user permission")
    String addUserPermission(Int userId, String action, String target) =
            auth.post($"{Path}/users/{userId}/permissions", $"{target}:{action}", Text);

    @Command("remove-user-permission", "Remove user permission")
    String removeUserPermission(Int userId, String action, String target) =
            auth.delete($"{Path}/users/{userId}/permissions", $"{target}:{action}", Text);

    @Command("add-user-group", "Add user to the group")
    String addUserToGroup(Int userId, Int groupId) =
            auth.post($"{Path}/users/{userId}/groups/{groupId}");

    @Command("remove-user-group", "Remove user from the group")
    String removeUserFromGroup(Int userId, Int groupId) =
            auth.delete($"{Path}/users/{userId}/groups/{groupId}");

    @Command("delete-user", "Delete user")
    String deleteUser(Int userId) = auth.delete($"{Path}/users/{userId}");

    // ----- "group management" operations ---------------------------------------------------------

    @Command("create-group", "Create group")
    String createGroup(String name) = auth.patch($"{Path}/groups/{name}");

    @Command("show-group", "Get group by id")
    String showGroup(Int groupId) = auth.patch($"{Path}/groups/{groupId}");

    @Command("find-group", "Find group by name")
    String findGroup(String name) = auth.get($"{Path}/groups?{name=}");

    @Command("add-group-permission", "Add group permission")
    String addGroupPermission(Int groupId, String action, String target) =
            auth.post($"{Path}/groups/{groupId}/permissions", $"{target}:{action}", Text);

    @Command("remove-group-permission", "Remove group permission")
    String removeGroupPermission(Int groupId, String action, String target) =
            auth.delete($"{Path}/groups/{groupId}/permissions", $"{target}:{action}", Text);

    @Command("add-group-group", "Add group to the group")
    String addGroupToGroup(@Desc("Group to add to another group")   Int groupId,
                           @Desc("Group to add the first group to") Int groupId2) =
            auth.post($"{Path}/groups/{groupId}/groups/{groupId2}");

    @Command("remove-group-group", "Remove group from the group")
    String removeGroupFromGroup(@Desc("Group to remove from another group")        Int groupId,
                                @Desc("Group to remove from the first group from") Int groupId2) =
            auth.delete($"{Path}/groups/{groupId}/groups/{groupId2}");

    @Command("delete-group", "Delete group")
    String deleteGroup(Int groupId) = auth.delete($"{Path}/groups/{groupId}");
}
