import convert.formats.Base64Format;

import crypto.Certificate;
import crypto.CertificateManager;
import crypto.CryptoPassword;
import crypto.KeyStore;

import common.Reporting;

import web.Client;
import web.HttpClient;
import web.ResponseIn;

/**
 * The proxy management API.
 *
 * @param receivers      the receivers associated with proxy servers
 * @param required       the minimum number of proxies that are required to be successfully updated for
 *                       the [updateProxyConfig] operation to claim success
 * @param updateTimeout  the timeout duration for receivers' updates
 */
service ProxyManager(Uri[] receivers, Int required, Duration updateTimeout)
        implements common.ProxyManager {

    @Inject Clock clock;

    private Uri[] receivers;
    private Int   required;

    assert() {
        assert 0 <= required <= receivers.size;
    }

    /**
     * The client used to talk to external services.
     */
    @Lazy Client client.calc() = new HttpClient();

    @Override
    Boolean updateProxyConfig(KeyStore keystore, CryptoPassword pwd,
                              String keyName, String hostName, Reporting report) {
        @Inject CertificateManager manager;

        Byte[] bytes  = manager.extractKey(keystore, pwd, keyName);
        String pemKey = $|-----BEGIN PRIVATE KEY-----
                         |{Base64Format.Instance.encode(bytes, pad=True, lineLength=64)}
                         |-----END PRIVATE KEY-----
                         |
                         ;

        StringBuffer buf = new StringBuffer();
        for (Certificate cert : keystore.getCertificateChain(keyName)) {
            buf.append($|-----BEGIN CERTIFICATE-----
                        |{Base64Format.Instance.encode(cert.toDerBytes(), pad=True, lineLength=64)}
                        |-----END CERTIFICATE-----
                        |
                      );
        }
        String pemCert = buf.toString();
        Time   cutoff  = clock.now + updateTimeout;

        @Future Boolean allDone;
        Future<Boolean> done = &allDone;

        @Volatile Int successCount = 0;

        for (Uri receiver : receivers) {
            Updater updater = new Updater(receiver, pemKey, pemCert, hostName, report);
            Boolean success = updater.updateProxy^(cutoff);
            &success.whenComplete((r, x) -> {
                if (r == True) {
                    if (++successCount >= required) {
                        done.complete(True);
                    }
                } else {
                    // this can only be caused by a timeout
                    done.complete(False);
                }
            });
        }
        return allDone;
    }


    @Override
    void removeProxyConfig(String hostName, Reporting report) {
        for (Uri receiver : receivers) {
            Boolean success;
            try (val _ = new Timeout(updateTimeout)) {
                ResponseIn response = client.delete(receiver.with(path=$"/nginx/{hostName}"));
                success = response.status == OK;
            } catch (Exception e) {
                success = False;
            }

            if (!success) {
                report($|Error: Failed to remove "{hostName}" route from the proxy server "{receiver}"
                      );
            }
        }
    }

    /**
     * A simple updater service that is used to communicate with a receiver.
     */
    service Updater(Uri receiver, String pemKey, String pemCert, String hostName, Reporting report) {
        /**
         * Async update.
         */
        Boolean updateProxy(Time cutoff) {
            Time now = clock.now;
            if (now > cutoff) {
                return False;
            }

            try (val _ = new Timeout(cutoff - now)) {
                if (update()) {
                    return True;
                }
            } catch (TimedOut e) {
                return False;
            }

            // repeat in two seconds
            @Future Boolean done;
            clock.schedule(Duration.ofSeconds(2), () -> {
                done = updateProxy^(cutoff);
            });
            return done;
        }

        /**
         * Internal synchronous operation.
         */
        private Boolean update() {
            Boolean success;
            String  reason;
            try {
                ResponseIn response = client.put(
                        receiver.with(path=$"/nginx/{hostName}/key"), pemKey, Text);

                if (response.status == OK) {
                    response = client.put(
                        receiver.with(path=$"/nginx/{hostName}/cert"), pemCert, Text);
                }
                success = response.status == OK;
                reason  = $"Status: {response.status}";
            } catch (Exception e) {
                success = False;
                reason  = e.message;
            }

            if (!success) {
                report($|Error: Failed to update the route for "{hostName}" at the proxy server \
                        |"{receiver}" reason="{reason}"
                      );
            }
            return success;
        }
    }
}