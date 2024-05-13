/**
 * The platform host service.
 */
module host.xqiz.it {
    package common import common.xqiz.it;
    package stub   import stub.xqiz.it;

    package crypto import crypto.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    /**
     * Bootstrapping: configure and return the HostManager.
     */
    common.HostManager configure(Directory accountsDir) {
        HostManager mgr = new HostManager(accountsDir);
        return &mgr.maskAs(common.HostManager);
    }
}