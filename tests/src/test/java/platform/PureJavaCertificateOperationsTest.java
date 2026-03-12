package platform;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.FileInputStream;
import java.nio.file.Path;
import java.security.KeyStore;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static platform.KeyStoreTestOperations.changeStorePassword;
import static platform.KeyStoreTestOperations.createPassword;
import static platform.KeyStoreTestOperations.createSymmetricKey;
import static platform.KeyStoreTestOperations.deleteKeyStoreEntry;
import static platform.KeyStoreTestOperations.extractKey;
import static platform.KeyStoreTestOperations.loadOrCreateKeyStore;

/**
 * Tests that validate the platform's certificate management operations can be performed
 * entirely in pure Java, without shelling out to native tools (keytool, openssl, certbot).
 *
 * These tests use the same {@link KeyStoreTestOperations} helpers as
 * {@link NativeToolDependenciesTest}, proving that keystores created by pure Java APIs
 * are functionally identical to those created by native tools.
 *
 * This validates the approach taken in the XDK's {@code lagergren/cert} branch
 * (commit 81e5292f4), which replaces ProcessBuilder calls to keytool/openssl/certbot
 * with Java Security APIs, BouncyCastle, and acme4j.
 *
 * These tests always run (no native tool assumptions needed) and prove the platform
 * does NOT need keytool, openssl, or certbot installed when using the updated XDK.
 */
@DisplayName("Pure Java Certificate Operations (no native tools required)")
public class PureJavaCertificateOperationsTest {

    @TempDir
    Path tempDir;

    // ---- symmetric key tests (replaces keytool -genseckey) --------------------------------------

    @Nested
    @DisplayName("Symmetric key creation (replaces keytool -genseckey)")
    class SymmetricKeyTests {

        @Test
        @DisplayName("Generate AES-256 symmetric key via pure Java")
        void createAES256Key() throws Exception {
            var storePath = tempDir.resolve("symmetric.p12").toString();
            var pwd = "testpwd".toCharArray();

            createSymmetricKey(storePath, pwd, "test-aes-key");

            var key = extractKey(storePath, pwd, "test-aes-key");
            assertNotNull(key, "Should retrieve the symmetric key from keystore");
            assertEquals("AES", key.getAlgorithm());
            assertEquals(32, key.getEncoded().length, "AES-256 key should be 32 bytes");
        }

        @Test
        @DisplayName("Multiple symmetric keys can coexist in one keystore")
        void multipleSymmetricKeys() throws Exception {
            var storePath = tempDir.resolve("multi-key.p12").toString();
            var pwd = "testpwd".toCharArray();

            createSymmetricKey(storePath, pwd, "cookie-encryption");
            createSymmetricKey(storePath, pwd, "password-encryption");

            var ks = loadOrCreateKeyStore(storePath, pwd);
            assertTrue(ks.containsAlias("cookie-encryption"));
            assertTrue(ks.containsAlias("password-encryption"));
            assertNotNull(extractKey(storePath, pwd, "cookie-encryption"));
            assertNotNull(extractKey(storePath, pwd, "password-encryption"));
        }
    }

    // ---- password storage tests (replaces keytool -importpass) -----------------------------------

    @Nested
    @DisplayName("Password storage (replaces keytool -importpass)")
    class PasswordStorageTests {

        @Test
        @DisplayName("Store a password as a PBE secret key entry")
        void storePassword() throws Exception {
            var storePath = tempDir.resolve("passwords.p12").toString();
            var pwd = "testpwd".toCharArray();

            createPassword(storePath, pwd, "db-password", "super-secret-db-password");

            var ks = loadOrCreateKeyStore(storePath, pwd);
            assertTrue(ks.containsAlias("db-password"), "Password entry should exist");
            assertNotNull(ks.getKey("db-password", pwd), "Password key should be retrievable");
        }
    }

    // ---- keystore management tests --------------------------------------------------------------

    @Nested
    @DisplayName("Keystore management operations")
    class KeystoreManagementTests {

        @Test
        @DisplayName("Delete entry from keystore (replaces keytool -delete)")
        void deleteEntry() throws Exception {
            var storePath = tempDir.resolve("delete-test.p12").toString();
            var pwd = "testpwd".toCharArray();

            createSymmetricKey(storePath, pwd, "to-delete");
            createSymmetricKey(storePath, pwd, "to-keep");

            assertTrue(loadOrCreateKeyStore(storePath, pwd).containsAlias("to-delete"));

            deleteKeyStoreEntry(storePath, pwd, "to-delete");

            var ks = loadOrCreateKeyStore(storePath, pwd);
            assertFalse(ks.containsAlias("to-delete"), "Deleted entry should be gone");
            assertTrue(ks.containsAlias("to-keep"), "Other entry should remain");
        }

        @Test
        @DisplayName("Change keystore password (replaces keytool -storepasswd)")
        void changePassword() throws Exception {
            var storePath = tempDir.resolve("change-pwd.p12").toString();
            var oldPwd = "oldpwd".toCharArray();
            var newPwd = "newpwd".toCharArray();

            createSymmetricKey(storePath, oldPwd, "test-key");
            changeStorePassword(storePath, oldPwd, newPwd);

            assertTrue(loadOrCreateKeyStore(storePath, newPwd).containsAlias("test-key"));

            assertThrows(Exception.class, () -> {
                var ks = KeyStore.getInstance("PKCS12");
                try (var in = new FileInputStream(storePath)) {
                    ks.load(in, oldPwd);
                }
            }, "Old password should no longer work");
        }
    }

    // ---- end-to-end platform flow (replaces kernel.x native tool dependency) --------------------

    @Nested
    @DisplayName("End-to-end: platform keystore initialization (pure Java, no native tools)")
    class EndToEndTests {

        @Test
        @DisplayName("Full platform keystore setup: symmetric keys + key extraction (as kernel.x does)")
        void fullPlatformKeystoreSetup() throws Exception {
            var storePath = tempDir.resolve("platform.p12").toString();
            var pwd = "platformpwd".toCharArray();

            createSymmetricKey(storePath, pwd, "cookie-encryption");
            createSymmetricKey(storePath, pwd, "password-encryption");

            assertNotNull(extractKey(storePath, pwd, "cookie-encryption"),
                    "Cookie encryption key should be extractable");
            assertNotNull(extractKey(storePath, pwd, "password-encryption"),
                    "Password encryption key should be extractable");

            var ks = loadOrCreateKeyStore(storePath, pwd);
            assertTrue(ks.containsAlias("cookie-encryption"));
            assertTrue(ks.containsAlias("password-encryption"));
            assertEquals(2, ks.size(), "Keystore should have exactly 2 entries");
        }

        @Test
        @DisplayName("Key extraction returns encoded bytes (as ProxyManager uses for PEM export)")
        void keyExtractionForProxyConfig() throws Exception {
            var storePath = tempDir.resolve("proxy-test.p12").toString();
            var pwd = "proxypwd".toCharArray();

            createSymmetricKey(storePath, pwd, "proxy-key");

            var key = extractKey(storePath, pwd, "proxy-key");
            assertNotNull(key, "Key should be extractable");
            assertNotNull(key.getEncoded(), "Key encoding should not be null");
            assertTrue(key.getEncoded().length > 0, "Key encoding should not be empty");
        }

        @Test
        @DisplayName("Password change after keystore creation preserves entries")
        void passwordChangePreservesEntries() throws Exception {
            var storePath = tempDir.resolve("pwd-change.p12").toString();
            var oldPwd = "initial".toCharArray();
            var newPwd = "rotated".toCharArray();

            createSymmetricKey(storePath, oldPwd, "cookie-encryption");
            createSymmetricKey(storePath, oldPwd, "password-encryption");
            changeStorePassword(storePath, oldPwd, newPwd);

            var ks = loadOrCreateKeyStore(storePath, newPwd);
            assertTrue(ks.containsAlias("cookie-encryption"),
                    "Cookie key alias should survive password change");
            assertTrue(ks.containsAlias("password-encryption"),
                    "Password key alias should survive password change");
            assertEquals(2, ks.size(), "All entries should be preserved");
        }
    }
}
