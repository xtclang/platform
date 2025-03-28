/*
 * Base class for core services.
 */
@Abstract
@WebService("")
service CoreService {
    construct() {
        accountManager = ControllerConfig.accountManager;
        hostManager    = ControllerConfig.hostManager;
        httpServer     = ControllerConfig.httpServer;
        baseDomain     = ControllerConfig.baseDomain;
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
     * The HttpServer.
     */
    protected HttpServer httpServer;

    /**
     * The base domain name.
     */
    protected String baseDomain;

    /**
     * The current account name.
     */
    String accountName.get() = this.session.is(SessionData)?.accountName : assert;
}