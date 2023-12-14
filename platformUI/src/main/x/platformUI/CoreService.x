/*
 * Base class for core services.
 */
@Abstract
@WebService("")
service CoreService {
    construct() {
        accountManager = ControllerConfig.accountManager;
        hostManager    = ControllerConfig.hostManager;
        router         = ControllerConfig.router;
    }

    /**
     * The account manager.
     */
    protected AccountManager accountManager;

    /**
     * The host manager.
     */
    protected HostManager hostManager;

    /**
     * The router.
     */
    protected Router router;

    /**
     * The current account name.
     */
    String accountName.get() {
        assert SessionData session := this.session.is(SessionData);
        return session.accountName? : "";
    }
}