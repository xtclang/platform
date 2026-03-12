package platform;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.math.BigInteger;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.security.cert.Certificate;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;

import javax.crypto.KeyGenerator;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/**
 * Shared keystore operations used by both the native-tool tests and the pure-Java tests.
 *
 * These operations mirror the XDK's {@code KeyStoreOperations} class from the
 * {@code lagergren/cert} branch. By using the same helper methods for verification
 * in both test classes, we prove that keystores produced by native tools (keytool/openssl)
 * and keystores produced by pure Java APIs are interchangeable.
 */
public final class KeyStoreTestOperations {

    private KeyStoreTestOperations() {}

    // ---- keystore I/O ---------------------------------------------------------------------------

    /**
     * Load an existing PKCS12 keystore or create a new empty one.
     * Mirrors {@code KeyStoreOperations.loadOrCreateKeyStore} from the lagergren/cert branch.
     */
    public static KeyStore loadOrCreateKeyStore(String path, char[] pwd) throws Exception {
        var keyStore = KeyStore.getInstance("PKCS12");
        var file = new File(path);
        if (file.exists()) {
            try (var in = new FileInputStream(file)) {
                keyStore.load(in, pwd);
            }
        } else {
            keyStore.load(null, pwd);
        }
        return keyStore;
    }

    /**
     * Save a keystore to disk.
     * Mirrors {@code KeyStoreOperations.saveKeyStore} from the lagergren/cert branch.
     */
    public static void saveKeyStore(KeyStore keyStore, String path, char[] pwd) throws Exception {
        try (var out = new FileOutputStream(path)) {
            keyStore.store(out, pwd);
        }
    }

    // ---- entry deletion -------------------------------------------------------------------------

    /**
     * Delete an entry from a keystore, silently ignoring errors.
     * Mirrors {@code KeyStoreOperations.deleteKeyStoreEntry} from the lagergren/cert branch.
     */
    public static void deleteKeyStoreEntry(String path, char[] pwd, String alias) {
        try {
            var file = new File(path);
            if (!file.exists()) {
                return;
            }
            var keyStore = loadOrCreateKeyStore(path, pwd);
            if (keyStore.containsAlias(alias)) {
                keyStore.deleteEntry(alias);
                saveKeyStore(keyStore, path, pwd);
            }
        } catch (Exception ignored) {
        }
    }

    // ---- symmetric key creation -----------------------------------------------------------------

    /**
     * Generate an AES-256 symmetric key and store it in a PKCS12 keystore.
     * Mirrors {@code KeyStoreOperations.createSymmetricKey} from the lagergren/cert branch.
     * Replaces: {@code keytool -genseckey -keyalg AES -keysize 256}
     */
    public static void createSymmetricKey(String path, char[] pwd, String alias) throws Exception {
        deleteKeyStoreEntry(path, pwd, alias);

        var keyGen = KeyGenerator.getInstance("AES");
        keyGen.init(256, new SecureRandom());
        var secretKey = keyGen.generateKey();

        var keyStore = loadOrCreateKeyStore(path, pwd);
        keyStore.setEntry(alias,
                new KeyStore.SecretKeyEntry(secretKey),
                new KeyStore.PasswordProtection(pwd));
        saveKeyStore(keyStore, path, pwd);
    }

    // ---- password storage -----------------------------------------------------------------------

    /**
     * Store a password as a PBE secret key entry in a PKCS12 keystore.
     * Mirrors {@code KeyStoreOperations.createPassword} from the lagergren/cert branch.
     * Replaces: {@code keytool -importpass} with stdin input.
     */
    public static void createPassword(String path, char[] pwd, String alias, String pwdValue)
            throws Exception {
        deleteKeyStoreEntry(path, pwd, alias);

        var pbeKey = SecretKeyFactory.getInstance("PBE")
                .generateSecret(new PBEKeySpec(pwdValue.toCharArray()));

        var keyStore = loadOrCreateKeyStore(path, pwd);
        keyStore.setEntry(alias,
                new KeyStore.SecretKeyEntry(pbeKey),
                new KeyStore.PasswordProtection(pwd));
        saveKeyStore(keyStore, path, pwd);
    }

    // ---- password change ------------------------------------------------------------------------

    /**
     * Change the password on a PKCS12 keystore.
     * Mirrors {@code KeyStoreOperations.changeStorePassword} from the lagergren/cert branch.
     * Replaces: {@code keytool -storepasswd}
     */
    public static void changeStorePassword(String path, char[] oldPwd, char[] newPwd)
            throws Exception {
        var keyStore = loadOrCreateKeyStore(path, oldPwd);
        saveKeyStore(keyStore, path, newPwd);
    }

    // ---- key extraction -------------------------------------------------------------------------

    /**
     * Extract a key from a PKCS12 keystore file.
     * Mirrors {@code KeyStoreOperations.extractKey} from the lagergren/cert branch.
     * Used by ProxyManager for PEM export.
     */
    public static java.security.Key extractKey(String path, char[] pwd, String alias) {
        try {
            var keyStore = loadOrCreateKeyStore(path, pwd);
            return keyStore.getKey(alias, pwd);
        } catch (Exception e) {
            return null;
        }
    }
}
