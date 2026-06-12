import crypto.CryptoPassword;
import crypto.KeyStore;


/**
 * The proxy management API.
 */
interface ProxyManager {

    /**
     * Maximum allowed update duration.
     */
    @RO Duration updateTimeout;

    /**
     * Send the proxy config updates updates to all proxies. The success of this operation may
     * depend on the configuration of the required proxies and the timeout.
     *
     * @param keystore  the keystore
     * @param pwd       the password for the keystore
     * @param keyName   the key name for the key/certificate pair
     * @param hostName  the host name to be updated
     * @param report    the function to report errors to
     *
     * @return `True` if the proxy configuration was successfully updated
     */
     Boolean updateProxyConfig(KeyStore keystore, CryptoPassword pwd, String keyName, String hostName,
                               Reporting report);

    /**
     * Notify all proxies that a config needs to be removed.
     *
     * @param hostName  the host name to be removed
     * @param report    the function to report errors to
     */
    void removeProxyConfig(String hostName, Reporting report);

    /**
     * Trivial "do nothing" implementation.
     */
    static ProxyManager NoProxies = new ProxyManager() {
        construct() {} finally { makeImmutable(); }

        @Override
        Boolean updateProxyConfig(KeyStore keystore, CryptoPassword pwd,
                               String keyName, String hostName, Reporting report) = True;

        @Override
        void removeProxyConfig(String hostName, Reporting report) {}
    };
}