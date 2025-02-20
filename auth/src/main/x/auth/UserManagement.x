/**
 * Web CLI commands for auth user management (see [UserEndpoint] web service).
 */
import webcli.*;

class UserManagement {
    @Inject Console console;

    /**
     * The URI of the [UserEndpoint] web service.
     */
    static String Path = "/.well-known/auth/mgmt";

    // ----- "self management" operations ----------------------------------------------------------

    @Command("user", "Show current user")
    String getUser() = auth.get($"{Path}/users/me");

    @Command("password", "Change password for current user")
    void changePassword(@NoEcho String oldPassword = "", @NoEcho String newPassword = "") {
        if (oldPassword.empty || newPassword.empty) {
            do {
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

        (_, HttpStatus status) = auth.patch($"{Path}/users/me/password", $"{b64Old}:{b64New}", Text);

        if (status == OK) {
            Gateway.resetClient(uriString=Gateway.serverUri(), authString=$"admin:{newPassword}");
        } else {
            auth.print($"Failed to reset the password: {status}");
        }
    }

    @Command("create-my-entitlement", "Create an entitlement for the current user")
    String createMyEntitlement(String name) {
        String key = auth.post($"{Path}/users/me/entitlements/{name}");

        console.print("Make sure to copy your entitlement token now. You won’t be able to see it again!");
        return key;
    }

    @Command("list-my-entitlements", "Find the entitlement for the current user by name")
    String listMyEntitlements() = auth.get($"{Path}/users/me/entitlements");

    @Command("find-my-entitlement", "Find the entitlement for the current user by name")
    String findMyEntitlement(String name) = auth.get($"{Path}/users/me/entitlements/{name}");

    @Command("set-my-entitlement-permissions", "Set the permission for the current user entitlement")
    String addMyEntitlementPermission(Int entitlementId,
                              @Desc("Comma delimited list of permissions") String permText) =
            auth.post($"{Path}/users/me/entitlements/{entitlementId}/permissions", permText, Text);

    @Command("delete-my-entitlement", "Delete the entitlement for the current user")
    String deleteMyEntitlement(Int entitlementId) =
            auth.delete($"{Path}/users/me/entitlements/{entitlementId}");

    // ----- user management operations ------------------------------------------------------------

    @Command("create-user", "Create user")
    String createUser(String name, @NoEcho String password) =
            auth.post($"{Path}/users/{name}", password, Text);

    @Command("show-user", "Get user by id")
    String showUser(Int userId) = auth.get($"{Path}/users/{userId}");

    @Command("find-user", "Find user by name")
    String findUser(String name) = auth.get($"{Path}/users?{name=}");

    @Command("reset-password", "Reset the password")
    String resetPassword(Int userId, @NoEcho String password) =
            auth.patch($"{Path}/users/{userId}/password", password, Text);

    @Command("set-user-permissions", "Set user permissions")
    String setUserPermission(Int userId,
                             @Desc("Comma delimited list of permissions") String permText) =
            auth.post($"{Path}/users/{userId}/permissions", permText, Text);

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
    String createGroup(String name) = auth.post($"{Path}/groups/{name}");

    @Command("show-group", "Get group by id")
    String showGroup(Int groupId) = auth.get($"{Path}/groups/{groupId}");

    @Command("find-group", "Find group by name")
    String findGroup(String name) = auth.get($"{Path}/groups?{name=}");

    @Command("set-group-permissions", "Set group permission")
    String addGroupPermission(Int groupId,
                              @Desc("Comma delimited list of permissions") String permText) =
            auth.post($"{Path}/groups/{groupId}/permissions", permText, Text);

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

    // ----- "entitlement management" operations ----------------------------------------------------

    @Command("create-entitlement", "Create entitlement")
    String createEntitlement(Int userId, String name) = auth.post($"{Path}/users/{userId}/entitlements/{name}");

    @Command("show-entitlement", "Get entitlement by id")
    String showEntitlement(Int entitlementId) = auth.get($"{Path}/entitlements/{entitlementId}");

    @Command("list-entitlements", "Find the entitlement for the current user by name")
    String listEntitlements(Int userId) = auth.get($"{Path}/users/{userId}/entitlements");

    @Command("find-entitlement", "Find entitlement for the user by name")
    String findEntitlement(Int userId, String name) = auth.get($"{Path}/users/{userId}/entitlements/{name}");

    @Command("set-entitlement-permissions", "Set entitlement permission")
    String addEntitlementPermission(Int entitlementId,
                              @Desc("Comma delimited list of permissions") String permText) =
            auth.post($"{Path}/entitlements/{entitlementId}/permissions", permText, Text);

    @Command("delete-entitlement", "Delete entitlement")
    String deleteEntitlement(Int entitlementId) = auth.delete($"{Path}/entitlements/{entitlementId}");
}
