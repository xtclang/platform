/**
 * The platform host service.
 */
module host.xqiz.it {
    package common    import common.xqiz.it;
    package challenge import challenge.xqiz.it;
    package stub      import stub.xqiz.it;

    package convert import convert.xtclang.org;
    package crypto  import crypto.xtclang.org;
    package net     import net.xtclang.org;
    package web     import web.xtclang.org;
    package xenia   import xenia.xtclang.org;

    /**
     * Bootstrapping: configure and return the HostManager.
     */
    common.HostManager configure(xenia.HttpServer httpServer, Directory accountsDir,
                                 net.Uri[] receivers) {
        HostManager mgr = new HostManager(httpServer, accountsDir, receivers);
        return &mgr.maskAs(common.HostManager);
    }
}