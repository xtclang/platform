/**
 * The package for commonly used names.
 */
package names {

    /**
     * The keystore name for any of the platform managed keystores.
     */
    static String KeyStoreName = "keystore.p12";

    /**
     * The name of the Tls key-pair in the platform keystore.
     */
    static String PlatformTlsKey = "platform";

    /**
     * The name of the cookie encryption key in any of the platform managed keystores.
     */
    static String CookieEncryptionKey = "cookies";

    /**
     * The name of the password encryption key in any of the platform managed keystore. This key is
     * used to encode various passwords before storing them in the corresponding DB.
     */
    static String PasswordEncryptionKey = "passwords";

    /**
     * The platform Realm name.
     */
    static String PlatformRealm = "platform";
}
