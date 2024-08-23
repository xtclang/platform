import convert.formats.Base64Format;

import crypto.Certificate;
import crypto.CertificateManager;
import crypto.CryptoPassword;
import crypto.KeyStore;

import common.Reporting;

import net.Uri;

import web.Client;
import web.HttpClient;
import web.ResponseIn;

/**
 * The proxy management API.
 */
service ProxyManager(Uri[] receivers)
        implements common.ProxyManager {

    /**
     * The receivers associated with proxy servers.
     */
    private Uri[] receivers;

    /**
     * The client used to talk to external services.
     */
    @Lazy Client client.calc() = new HttpClient();

    /**
     * The timeout duration for receivers' updates.
     */
    static Duration receiverTimeout = Duration.ofSeconds(5);

    @Override
    void updateProxyConfig(KeyStore keystore, CryptoPassword pwd,
                           String keyName, String hostName, Reporting report) {

        @Inject CertificateManager manager;

        for (Uri receiver : receivers) {
            Byte[] bytes  = manager.extractKey(keystore, pwd, keyName);
            String pemKey = $|-----BEGIN PRIVATE KEY-----
                             |{Base64Format.Instance.encode(bytes, pad=True, lineLength=64)}
                             |-----END PRIVATE KEY-----
                             |
                             ;

            Boolean success;
            try (val t = new Timeout(receiverTimeout)) {
                ResponseIn response = client.put(
                        receiver.with(path=$"/nginx/{hostName}/key"), pemKey, Text);

                if (response.status == OK) {
                    StringBuffer pemCert = new StringBuffer();
                    for (Certificate cert : keystore.getCertificateChain(keyName)) {
                        pemCert.append(
                                $|-----BEGIN CERTIFICATE-----
                                 |{Base64Format.Instance.encode(cert.toDerBytes(), pad=True, lineLength=64)}
                                 |-----END CERTIFICATE-----
                                 |
                                 );
                    }
                    response = client.put(
                        receiver.with(path=$"/nginx/{hostName}/cert"), pemCert.toString(), Text);
                }
                success = response.status == OK;
            } catch (Exception e) {
                success = False;
            }

            if (!success) {
                report($|Failed to update the route for "{hostName}" at the proxy server "{receiver}"
                      );
            }
        }
    }

    @Override
    void removeProxyConfig(String hostName, Reporting report) {
        for (Uri receiver : receivers) {
            Boolean success;
            try (val t = new Timeout(receiverTimeout)) {
                ResponseIn response = client.delete(receiver.with(path=$"/nginx/{hostName}"));
                success = response.status == OK;
            } catch (Exception e) {
                success = False;
            }

            if (!success) {
                report($|Failed to remove "{hostName}" route from the proxy server "{receiver}"
                      );
            }
        }
    }
}