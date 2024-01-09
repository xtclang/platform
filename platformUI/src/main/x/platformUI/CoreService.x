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
        keystore       = ControllerConfig.keystore;
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
     * The keystore for the platform.
     */
    protected KeyStore keystore;

    /**
     * The current account name.
     */
    String accountName.get() {
        assert SessionData session := this.session.is(SessionData);
        return session.accountName? : "";
    }
}