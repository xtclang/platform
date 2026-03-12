/**
 * xUnit tests for the XDK's CertificateManager native bridge.
 *
 * These tests verify that the CertificateManager injection works and that
 * all keystore operations required by the platform (self-signed certificates,
 * symmetric keys, password storage, key extraction) function correctly.
 *
 * On XDK master, these operations shell out to native tools (keytool, openssl, certbot).
 * On the lagergren/cert branch, they use pure Java APIs (BouncyCastle, acme4j).
 * These tests should pass with BOTH implementations, proving the Java version
 * is a drop-in replacement.
 */
module CertificateManagerTest {

    package crypto import crypto.xtclang.org;

    import crypto.CertificateManager;
    import crypto.CryptoKey;
    import crypto.CryptoPassword;
    import crypto.KeyStore;

    /**
     * Tests for symmetric key operations.
     *
     * These mirror what kernel.x does on first boot when it creates the
     * cookie-encryption and password-encryption keys.
     */
    class SymmetricKeyTest {

        @Test
        void shouldCreateSymmetricKey() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store = testDir.fileFor("sym-key-test.p12");
            String pwd   = "test-password";
            String alias = "test-symmetric";

            try {
                manager.createSymmetricKey(store, pwd, alias);

                assert store.exists as "Keystore file should be created";

                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;
                assert CryptoKey key := keystore.getKey(alias)
                    as $"Symmetric key '{alias}' should exist in keystore";
            } finally {
                store.delete();
            }
        }

        @Test
        void shouldCreateMultipleSymmetricKeys() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store = testDir.fileFor("multi-sym-test.p12");
            String pwd   = "test-password";

            try {
                manager.createSymmetricKey(store, pwd, "cookies");
                manager.createSymmetricKey(store, pwd, "passwords");

                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;
                assert keystore.getKey("cookies")
                    as "Cookie encryption key should exist";
                assert keystore.getKey("passwords")
                    as "Password encryption key should exist";
            } finally {
                store.delete();
            }
        }
    }

    /**
     * Tests for self-signed certificate creation.
     *
     * These mirror what platformUI.ensureCertificate() does when creating
     * the initial platform TLS certificate with the "self" provider.
     */
    class SelfSignedCertificateTest {

        @Test
        void shouldCreateSelfSignedCertificate() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store = testDir.fileFor("self-cert-test.p12");
            String pwd   = "test-password";
            String alias = "platform";
            String dName = CertificateManager.distinguishedName("test.xqiz.it",
                                org="Test", orgUnit="Platform Test");

            try {
                manager.createCertificate(store, pwd, alias, dName);

                assert store.exists as "Keystore file should be created";

                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                assert CryptoKey keyPair := keystore.getKey(alias)
                    as $"Key pair '{alias}' should exist in keystore";

                assert keystore.getCertificate(alias)
                    as $"Certificate '{alias}' should exist in keystore";
            } finally {
                store.delete();
            }
        }

        @Test
        void shouldCreateCertificateAndSymmetricKeysTogether() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store = testDir.fileFor("combined-test.p12");
            String pwd   = "test-password";
            String dName = CertificateManager.distinguishedName("combined.xqiz.it");

            try {
                // This is the exact sequence kernel.x performs on first boot:
                // 1. Create symmetric keys first
                manager.createSymmetricKey(store, pwd, "cookies");
                manager.createSymmetricKey(store, pwd, "passwords");

                // 2. Then create the TLS certificate
                manager.createCertificate(store, pwd, "platform", dName);

                // Verify all three entries exist and are accessible
                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                assert keystore.getKey("cookies")
                    as "Cookie encryption key should exist";
                assert keystore.getKey("passwords")
                    as "Password encryption key should exist";
                assert keystore.getKey("platform")
                    as "TLS key pair should exist";
                assert keystore.getCertificate("platform")
                    as "TLS certificate should exist";
            } finally {
                store.delete();
            }
        }
    }

    /**
     * Tests for password storage operations.
     */
    class PasswordStorageTest {

        @Test
        void shouldStoreAndRetrievePassword() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store = testDir.fileFor("pwd-store-test.p12");
            String pwd   = "test-password";

            try {
                manager.createPassword(store, pwd, "db-password", "super-secret");

                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;
                assert CryptoPassword dbPwd := keystore.getPassword("db-password")
                    as "Password entry should be retrievable";
            } finally {
                store.delete();
            }
        }
    }

    /**
     * Tests for key extraction (used by ProxyManager for PEM export).
     */
    class KeyExtractionTest {

        @Test
        void shouldExtractKeyBytes() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store = testDir.fileFor("extract-test.p12");
            String pwd   = "test-password";
            String alias = "extract-cert";
            String dName = CertificateManager.distinguishedName("extract.xqiz.it");

            try {
                manager.createCertificate(store, pwd, alias, dName);

                // Extract key in DER format (as ProxyManager does for PEM conversion)
                Byte[] keyBytes = manager.extractKey(store, pwd, alias);
                assert keyBytes.size > 0
                    as "Extracted key bytes should not be empty";
            } finally {
                store.delete();
            }
        }

        @Test
        void shouldExtractKeyFromKeyStore() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store = testDir.fileFor("extract-ks-test.p12");
            String pwd   = "test-password";
            String alias = "ks-extract-cert";
            String dName = CertificateManager.distinguishedName("ks-extract.xqiz.it");

            try {
                manager.createCertificate(store, pwd, alias, dName);

                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                // Extract from KeyStore object (alternative signature)
                Byte[] keyBytes = manager.extractKey(keystore, pwd, alias);
                assert keyBytes.size > 0
                    as "Extracted key bytes from KeyStore should not be empty";
            } finally {
                store.delete();
            }
        }
    }

    /**
     * Tests for keystore password change.
     */
    class PasswordChangeTest {

        @Test
        void shouldChangeKeystorePassword() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store  = testDir.fileFor("pwd-change-test.p12");
            String oldPwd = "old-password";
            String newPwd = "new-password";

            try {
                manager.createSymmetricKey(store, oldPwd, "test-key");

                manager.changeStorePassword(store, oldPwd, newPwd);

                // Verify new password works
                @Inject(opts=new KeyStore.Info(store.contents, newPwd)) KeyStore keystore;
                assert keystore.getKey("test-key")
                    as "Key should be accessible with new password";
            } finally {
                store.delete();
            }
        }
    }

    /**
     * End-to-end test simulating the full platform keystore initialization
     * sequence that kernel.x performs on first boot.
     */
    class PlatformBootstrapTest {

        @Test
        void shouldPerformFullPlatformKeystoreInit() {
            @Inject("testOutput") Directory testDir;
            @Inject CertificateManager manager;

            File   store    = testDir.fileFor("platform-boot-test.p12");
            String pwd      = "platform-password";
            String hostName = "platform-test.xqiz.it";
            String dName    = CertificateManager.distinguishedName(hostName,
                                    org="XqizIt", orgUnit="Platform");

            try {
                // Phase 1: kernel.x creates symmetric keys if keystore doesn't exist
                manager.createSymmetricKey(store, pwd, "cookies");
                manager.createSymmetricKey(store, pwd, "passwords");

                // Phase 2: platformUI.ensureCertificate creates the TLS cert
                manager.createCertificate(store, pwd, "platform", dName);

                // Phase 3: kernel.x verifies keystore on subsequent boots
                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore keystore;

                assert keystore.getKey("cookies")
                    as "Cookie encryption key must exist for platform operation";
                assert keystore.getKey("passwords")
                    as "Password encryption key must exist for platform operation";
                assert CryptoKey tlsKey := keystore.getKey("platform")
                    as "TLS key pair must exist for HTTPS";
                assert keystore.getCertificate("platform")
                    as "TLS certificate must exist for HTTPS";

                // Phase 4: ProxyManager extracts the key for PEM export to nginx
                Byte[] extractedKey = manager.extractKey(keystore, pwd, "platform");
                assert extractedKey.size > 0
                    as "Key extraction must work for proxy configuration";

                // Phase 5: Store a password (for deployment credentials)
                manager.createPassword(store, pwd, "deploy-secret", "s3cret!");

                // Reload and verify everything is still intact
                @Inject(opts=new KeyStore.Info(store.contents, pwd)) KeyStore reloaded;
                assert reloaded.getKey("cookies");
                assert reloaded.getKey("passwords");
                assert reloaded.getKey("platform");
                assert reloaded.getCertificate("platform");
                assert reloaded.getPassword("deploy-secret");
            } finally {
                store.delete();
            }
        }
    }
}
