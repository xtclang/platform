import ecstasy.mgmt.Container;

import ecstasy.reflect.ModuleTemplate;

import common.ErrorLog;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;

import web.*;
import web.http.FormDataFile;
import web.responses.SimpleResponse;

/*
 * Dedicated service for user management.
 */
@WebService("/user")
service User() {

    construct() {
        accountManager = ControllerConfig.accountManager;
        hostManager    = ControllerConfig.hostManager;
    }

    /**
     * The account manager.
     */
    private AccountManager accountManager;

    /**
     * The host manager.
     */
    private HostManager hostManager;

    /**
     * The current account name.
     */
    String accountName.get() {
        return session?.userId? : "";
    }

    /*
     * Returns the current user id or `NoContent`
     */
    @Get("id")
    SimpleResponse getUserId() {
        return accountName == ""
            ? new SimpleResponse(HttpStatus.NoContent)
            : new SimpleResponse(HttpStatus.OK, Null, accountName.utf8());
    }

    /*
     * Used to trigger (digest) authentication request from the GUI
     */
    @Get("login")
    @LoginRequired
    String login() {
        return accountName;
    }

    /*
     * Logs out the current user
     */
    @Put("logout")
    HttpStatus signOut() {
        session?.deauthenticate();
        return HttpStatus.NoContent;
    }

}