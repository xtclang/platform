package platform;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.file.Path;
import java.security.KeyStore;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;
import static platform.KeyStoreTestOperations.createSymmetricKey;
import static platform.KeyStoreTestOperations.extractKey;
import static platform.KeyStoreTestOperations.loadOrCreateKeyStore;

/**
 * Integration tests verifying that native tools required by the XDK's
 * {@code xRTCertificateManager} (master branch) are installed and functional.
 *
 * The current XDK master uses ProcessBuilder to shell out to:
 * <ul>
 *   <li>{@code keytool} - Java KeyStore operations (ships with JDK)</li>
 *   <li>{@code openssl} - key generation, CSR creation, PKCS12 conversion</li>
 *   <li>{@code certbot} - Let's Encrypt ACME certificate provisioning</li>
 * </ul>
 *
 * Tests that require a tool not present on the system are skipped (not failed)
 * via JUnit assumptions, with installation instructions in the skip message.
 *
 * Keystores created by native tools are verified using {@link KeyStoreTestOperations},
 * the same shared helpers used by {@link PureJavaCertificateOperationsTest}. This proves
 * that native-tool-produced keystores are readable by pure Java APIs (and vice versa).
 */
@DisplayName("Native Tool Dependencies for XDK CertificateManager")
public class NativeToolDependenciesTest {

    @TempDir
    Path tempDir;

    // ---- tool availability checks ---------------------------------------------------------------

    private static boolean keytoolAvailable;
    private static boolean opensslAvailable;
    private static boolean certbotAvailable;

    private static final String KEYTOOL_INSTALL_HINT =
            "keytool ships with the JDK - ensure JAVA_HOME/bin is on your PATH";
    private static final String OPENSSL_INSTALL_HINT =
            "Install openssl: macOS: 'brew install openssl', " +
            "Ubuntu/Debian: 'sudo apt install openssl', " +
            "RHEL/Fedora: 'sudo dnf install openssl'";
    private static final String CERTBOT_INSTALL_HINT =
            "Install certbot: macOS: 'brew install certbot', " +
            "Ubuntu/Debian: 'sudo apt install certbot', " +
            "RHEL/Fedora: 'sudo dnf install certbot', " +
            "or via pip: 'pip install certbot'";

    @BeforeAll
    static void detectAvailableTools() {
        keytoolAvailable = isToolAvailable("keytool", "-help");
        opensslAvailable = isToolAvailable("openssl", "version");
        certbotAvailable = isToolAvailable("certbot", "--version");

        System.out.println("Native tool availability:");
        System.out.println("  keytool: " + (keytoolAvailable
                ? "FOUND" : "NOT FOUND *** " + KEYTOOL_INSTALL_HINT));
        System.out.println("  openssl: " + (opensslAvailable
                ? "FOUND" : "NOT FOUND - tests will be SKIPPED *** " + OPENSSL_INSTALL_HINT));
        System.out.println("  certbot: " + (certbotAvailable
                ? "FOUND" : "NOT FOUND - tests will be SKIPPED *** " + CERTBOT_INSTALL_HINT));
    }

    private static boolean isToolAvailable(String... cmd) {
        try {
            Process p = new ProcessBuilder(cmd).redirectErrorStream(true).start();
            p.getInputStream().readAllBytes();
            return p.waitFor(10, TimeUnit.SECONDS);
        } catch (Exception e) {
            return false;
        }
    }

    // ---- helpers --------------------------------------------------------------------------------

    private record CommandResult(int exitCode, String stdout, String stderr) {
        boolean succeeded() {
            return exitCode == 0;
        }
    }

    private static CommandResult run(String... cmd) throws Exception {
        ProcessBuilder pb = new ProcessBuilder(cmd);
        Process process = pb.start();

        String stdout;
        String stderr;
        try (var outReader = new BufferedReader(new InputStreamReader(process.getInputStream()));
             var errReader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
            stdout = String.join("\n", outReader.lines().toList());
            stderr = String.join("\n", errReader.lines().toList());
        }

        assertTrue(process.waitFor(30, TimeUnit.SECONDS),
                "Command timed out: " + String.join(" ", cmd));

        return new CommandResult(process.exitValue(), stdout, stderr);
    }

    // ---- keytool tests --------------------------------------------------------------------------

    @Nested
    @DisplayName("keytool (ships with JDK)")
    class KeytoolTests {

        @Test
        @DisplayName("keytool is available on PATH")
        void keytoolIsAvailable() throws Exception {
            assumeTrue(keytoolAvailable,
                    "keytool not found on PATH. " + KEYTOOL_INSTALL_HINT);

            CommandResult result = run("keytool", "-help");
            String combined = result.stdout + result.stderr;
            assertTrue(combined.contains("keytool") || combined.contains("Commands:"),
                    "keytool should produce recognizable output; got: " + combined);
        }

        @Test
        @DisplayName("keytool can create a self-signed certificate (RSA 2048, PKCS12)")
        void keytoolCanCreateSelfSignedCert() throws Exception {
            assumeTrue(keytoolAvailable,
                    "keytool not found on PATH. " + KEYTOOL_INSTALL_HINT);

            String storePath = tempDir.resolve("test-keystore.p12").toString();
            char[] password = "testpassword".toCharArray();

            CommandResult result = run(
                    "keytool", "-genkeypair",
                    "-keyalg", "RSA",
                    "-keysize", "2048",
                    "-validity", "90",
                    "-alias", "test-cert",
                    "-dname", "CN=test.example.com,O=Test,L=Test,ST=Test,C=US",
                    "-storetype", "PKCS12",
                    "-keystore", storePath,
                    "-storepass", new String(password)
            );
            assertEquals(0, result.exitCode,
                    "keytool -genkeypair should succeed; stderr: " + result.stderr);

            // Verify using shared pure-Java helpers (proves interoperability)
            KeyStore ks = loadOrCreateKeyStore(storePath, password);
            assertTrue(ks.containsAlias("test-cert"),
                    "KeyStore should contain the 'test-cert' alias");
            assertNotNull(extractKey(storePath, password, "test-cert"),
                    "Private key should be extractable via Java APIs");
        }

        @Test
        @DisplayName("keytool can generate a symmetric AES-256 key")
        void keytoolCanCreateSymmetricKey() throws Exception {
            assumeTrue(keytoolAvailable,
                    "keytool not found on PATH. " + KEYTOOL_INSTALL_HINT);

            String storePath = tempDir.resolve("test-symmetric.p12").toString();
            char[] password = "testpassword".toCharArray();

            CommandResult result = run(
                    "keytool", "-genseckey",
                    "-keyalg", "AES",
                    "-keysize", "256",
                    "-alias", "test-aes-key",
                    "-storetype", "PKCS12",
                    "-keystore", storePath,
                    "-storepass", new String(password)
            );
            assertEquals(0, result.exitCode,
                    "keytool -genseckey should succeed; stderr: " + result.stderr);

            // Verify using shared pure-Java helpers
            var key = extractKey(storePath, password, "test-aes-key");
            assertNotNull(key, "AES key should be extractable via Java APIs");
            assertEquals("AES", key.getAlgorithm());
            assertEquals(32, key.getEncoded().length, "AES-256 key should be 32 bytes");
        }

        @Test
        @DisplayName("keytool can import a password entry")
        void keytoolCanImportPassword() throws Exception {
            assumeTrue(keytoolAvailable,
                    "keytool not found on PATH. " + KEYTOOL_INSTALL_HINT);

            String storePath = tempDir.resolve("test-password.p12").toString();
            char[] password = "testpassword".toCharArray();

            ProcessBuilder pb = new ProcessBuilder(
                    "keytool", "-importpass",
                    "-alias", "test-pwd",
                    "-storetype", "PKCS12",
                    "-keystore", storePath,
                    "-storepass", new String(password)
            );
            Process process = pb.start();
            try (var out = process.getOutputStream()) {
                out.write("secret-value".getBytes());
            }
            assertTrue(process.waitFor(30, TimeUnit.SECONDS), "keytool -importpass timed out");
            assertEquals(0, process.exitValue(),
                    "keytool -importpass should succeed");

            // Verify using shared pure-Java helpers
            KeyStore ks = loadOrCreateKeyStore(storePath, password);
            assertTrue(ks.containsAlias("test-pwd"), "Password entry should exist");
        }
    }

    // ---- openssl tests --------------------------------------------------------------------------

    @Nested
    @DisplayName("openssl (required for certbot/Let's Encrypt flow)")
    class OpensslTests {

        @Test
        @DisplayName("openssl is available on PATH")
        void opensslIsAvailable() throws Exception {
            assumeTrue(opensslAvailable,
                    "openssl not found on PATH. " + OPENSSL_INSTALL_HINT);

            CommandResult result = run("openssl", "version");
            assertTrue(result.succeeded(),
                    "openssl version should succeed; stderr: " + result.stderr);
            assertTrue(result.stdout.toLowerCase().contains("openssl"),
                    "openssl version should identify itself; got: " + result.stdout);
        }

        @Test
        @DisplayName("openssl can generate an RSA 2048-bit private key")
        void opensslCanGenerateRSAKey() throws Exception {
            assumeTrue(opensslAvailable,
                    "openssl not found on PATH. " + OPENSSL_INSTALL_HINT);

            String keyPath = tempDir.resolve("test.key").toString();

            CommandResult result = run(
                    "openssl", "genpkey",
                    "-algorithm", "RSA",
                    "-out", keyPath,
                    "-pkeyopt", "rsa_keygen_bits:2048"
            );
            assertEquals(0, result.exitCode,
                    "openssl genpkey should succeed; stderr: " + result.stderr);

            File keyFile = new File(keyPath);
            assertTrue(keyFile.exists() && keyFile.length() > 0,
                    "Private key file should be created and non-empty");
        }

        @Test
        @DisplayName("openssl can create a CSR from a private key")
        void opensslCanCreateCSR() throws Exception {
            assumeTrue(opensslAvailable,
                    "openssl not found on PATH. " + OPENSSL_INSTALL_HINT);

            String keyPath = tempDir.resolve("test.key").toString();
            String csrPath = tempDir.resolve("test.csr").toString();

            run("openssl", "genpkey", "-algorithm", "RSA",
                    "-out", keyPath, "-pkeyopt", "rsa_keygen_bits:2048");

            CommandResult result = run(
                    "openssl", "req", "-new",
                    "-key", keyPath,
                    "-out", csrPath,
                    "-subj", "/CN=test.example.com/O=Test/L=Test/ST=Test/C=US"
            );
            assertEquals(0, result.exitCode,
                    "openssl req -new should succeed; stderr: " + result.stderr);

            File csrFile = new File(csrPath);
            assertTrue(csrFile.exists() && csrFile.length() > 0,
                    "CSR file should be created and non-empty");
        }

        @Test
        @DisplayName("openssl can convert PEM to PKCS12, readable by Java APIs")
        void opensslCanConvertToPKCS12() throws Exception {
            assumeTrue(opensslAvailable,
                    "openssl not found on PATH. " + OPENSSL_INSTALL_HINT);

            String keyPath = tempDir.resolve("test.key").toString();
            String certPath = tempDir.resolve("test.crt").toString();
            String p12Path = tempDir.resolve("test.p12").toString();
            char[] password = "testpwd".toCharArray();

            run("openssl", "genpkey", "-algorithm", "RSA",
                    "-out", keyPath, "-pkeyopt", "rsa_keygen_bits:2048");
            run("openssl", "req", "-new", "-x509",
                    "-key", keyPath, "-out", certPath, "-days", "1",
                    "-subj", "/CN=test.example.com");

            CommandResult result = run(
                    "openssl", "pkcs12", "-export",
                    "-out", p12Path,
                    "-inkey", keyPath,
                    "-in", certPath,
                    "-name", "test-alias",
                    "-passin", "pass:" + new String(password),
                    "-passout", "pass:" + new String(password)
            );
            assertEquals(0, result.exitCode,
                    "openssl pkcs12 -export should succeed; stderr: " + result.stderr);

            // Verify using shared pure-Java helpers (proves interoperability)
            KeyStore ks = loadOrCreateKeyStore(p12Path, password);
            assertTrue(ks.containsAlias("test-alias"),
                    "Converted PKCS12 should contain the alias");
            assertNotNull(extractKey(p12Path, password, "test-alias"),
                    "Private key should be extractable via Java APIs");
        }
    }

    // ---- certbot tests --------------------------------------------------------------------------

    @Nested
    @DisplayName("certbot (required for Let's Encrypt certificate provisioning)")
    class CertbotTests {

        @Test
        @DisplayName("certbot is available on PATH")
        void certbotIsAvailable() throws Exception {
            assumeTrue(certbotAvailable,
                    "certbot not found on PATH. " + CERTBOT_INSTALL_HINT);

            CommandResult result = run("certbot", "--version");
            String combined = result.stdout + result.stderr;
            assertTrue(combined.toLowerCase().contains("certbot"),
                    "certbot --version should identify itself; got: " + combined);
        }
    }

    // ---- end-to-end native tool flows -----------------------------------------------------------

    @Nested
    @DisplayName("End-to-end: native tool flows verified by Java APIs")
    class EndToEndFlowTests {

        @Test
        @DisplayName("Full self-signed flow: keytool cert + symmetric keys, verified by pure Java extraction")
        void selfSignedFlowWithKeyExtraction() throws Exception {
            assumeTrue(keytoolAvailable,
                    "keytool not found on PATH. " + KEYTOOL_INSTALL_HINT);

            String storePath = tempDir.resolve("platform.p12").toString();
            char[] password = "platformpwd".toCharArray();

            // Create cert with native keytool
            CommandResult result = run(
                    "keytool", "-genkeypair",
                    "-keyalg", "RSA", "-keysize", "2048", "-validity", "90",
                    "-alias", "platform-cert",
                    "-dname", "CN=platform.example.com,O=XqizIt,L=San Francisco,ST=CA,C=US",
                    "-storetype", "PKCS12",
                    "-keystore", storePath,
                    "-storepass", new String(password)
            );
            assertEquals(0, result.exitCode, "Self-signed cert creation should succeed");

            // Create symmetric key with native keytool
            result = run(
                    "keytool", "-genseckey",
                    "-keyalg", "AES", "-keysize", "256",
                    "-alias", "cookie-encryption",
                    "-storetype", "PKCS12",
                    "-keystore", storePath,
                    "-storepass", new String(password)
            );
            assertEquals(0, result.exitCode, "Symmetric key creation should succeed");

            // Verify everything using shared pure-Java helpers
            KeyStore ks = loadOrCreateKeyStore(storePath, password);
            assertNotNull(extractKey(storePath, password, "platform-cert"),
                    "Private key should be extractable via Java APIs");
            assertNotNull(extractKey(storePath, password, "cookie-encryption"),
                    "Symmetric key should be extractable via Java APIs");
            assertNotNull(ks.getCertificate("platform-cert"),
                    "Certificate should be retrievable via Java APIs");
        }

        @Test
        @DisplayName("keytool -importkeystore flow, verified by pure Java APIs")
        void importKeystoreFlow() throws Exception {
            assumeTrue(keytoolAvailable,
                    "keytool not found on PATH. " + KEYTOOL_INSTALL_HINT);

            String srcStorePath = tempDir.resolve("src.p12").toString();
            String dstStorePath = tempDir.resolve("dst.p12").toString();
            char[] password = "testpwd".toCharArray();

            run("keytool", "-genkeypair",
                    "-keyalg", "RSA", "-keysize", "2048", "-validity", "1",
                    "-alias", "imported-cert",
                    "-dname", "CN=import.example.com",
                    "-storetype", "PKCS12",
                    "-keystore", srcStorePath,
                    "-storepass", new String(password));

            // Create destination using pure Java helper (cross-approach interop)
            createSymmetricKey(dstStorePath, password, "existing-key");

            // Import from native-created source into Java-created destination
            CommandResult result = run(
                    "keytool", "-importkeystore",
                    "-srckeystore", srcStorePath,
                    "-srcstoretype", "PKCS12",
                    "-destkeystore", dstStorePath,
                    "-deststoretype", "PKCS12",
                    "-alias", "imported-cert",
                    "-srcstorepass", new String(password),
                    "-deststorepass", new String(password)
            );
            assertEquals(0, result.exitCode,
                    "keytool -importkeystore should succeed; stderr: " + result.stderr);

            // Verify using shared pure-Java helpers
            KeyStore ks = loadOrCreateKeyStore(dstStorePath, password);
            assertTrue(ks.containsAlias("existing-key"), "Java-created key should still exist");
            assertTrue(ks.containsAlias("imported-cert"), "Native-imported cert should be present");
        }

        @Test
        @DisplayName("openssl + keytool combined flow, verified by pure Java APIs")
        void opensslToKeytoolImportFlow() throws Exception {
            assumeTrue(keytoolAvailable,
                    "keytool not found on PATH. " + KEYTOOL_INSTALL_HINT);
            assumeTrue(opensslAvailable,
                    "openssl not found on PATH. " + OPENSSL_INSTALL_HINT);

            String keyPath = tempDir.resolve("domain.key").toString();
            String certPath = tempDir.resolve("domain.crt").toString();
            String tempP12Path = tempDir.resolve("domain.p12").toString();
            String storePath = tempDir.resolve("keystore.p12").toString();
            char[] password = "testpwd".toCharArray();

            // 1. Generate key with openssl
            run("openssl", "genpkey", "-algorithm", "RSA",
                    "-out", keyPath, "-pkeyopt", "rsa_keygen_bits:2048");

            // 2. Create self-signed cert with openssl (stand-in for Let's Encrypt)
            run("openssl", "req", "-new", "-x509",
                    "-key", keyPath, "-out", certPath, "-days", "1",
                    "-subj", "/CN=acme.example.com");

            // 3. Convert to PKCS12 with openssl
            run("openssl", "pkcs12", "-export",
                    "-out", tempP12Path,
                    "-inkey", keyPath,
                    "-in", certPath,
                    "-name", "acme-cert",
                    "-passin", "pass:" + new String(password),
                    "-passout", "pass:" + new String(password));

            // 4. Create target keystore with pure Java helper (cross-approach interop)
            createSymmetricKey(storePath, password, "cookie-key");

            // 5. Import with native keytool
            CommandResult result = run(
                    "keytool", "-importkeystore",
                    "-srckeystore", tempP12Path,
                    "-srcstoretype", "PKCS12",
                    "-destkeystore", storePath,
                    "-deststoretype", "PKCS12",
                    "-alias", "acme-cert",
                    "-srcstorepass", new String(password),
                    "-deststorepass", new String(password)
            );
            assertEquals(0, result.exitCode, "keytool import should succeed");

            // 6. Verify using shared pure-Java helpers
            assertNotNull(extractKey(storePath, password, "cookie-key"),
                    "Java-created symmetric key should be extractable");
            assertNotNull(extractKey(storePath, password, "acme-cert"),
                    "Native-imported ACME cert key should be extractable via Java APIs");
        }
    }
}
