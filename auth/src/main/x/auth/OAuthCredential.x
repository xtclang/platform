import sec.Credential;

/**
 * A `OAuthCredential` represents am OAuth identity provider.
 */
const OAuthCredential(String provider)
        extends Credential(Scheme) {

    /**
     * "oa" == OAuth
     */
    static String Scheme = "oa";


    // ----- properties ----------------------------------------------------------------------------

    @Override
    String[] locators.get() = [provider];
}