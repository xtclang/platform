/**
 * Web CLI commands for auth user management (see [AuthEndpoint] web service).
 */
import webcli.*;

class UserManagement {
    /**
     * The URI of the [AuthEndpoint] web service.
     */
    static String Path = "/.well-known/auth";

    @Command("user", "Show current user")
    String getUser() = auth.get($"{Path}/user");

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

        RequestOut request = Gateway.createRequest(POST, $"{Path}/pwd", $"{b64Old}:{b64New}", Text);
        (_, HttpStatus status) = Gateway.send(request);

        if (status == OK) {
            Gateway.resetClient(uriString=Gateway.serverUri(), authString=$"admin:{newPassword}");
        } else {
            auth.print($"Failed to reset the password: {status}");
        }
    }
}
