/**
 * The platform host service.
 */
module host.xqiz.it {
    package common import common.xqiz.it;
    package crypto import crypto.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    /**
     * Bootstrapping: configure and return the HostManager.
     */
    common.HostManager configure(Directory usersDir, crypto.KeyStore keystore) {
        HostManager mgr = new HostManager(usersDir, keystore);
        return &mgr.maskAs(common.HostManager);
    }
}