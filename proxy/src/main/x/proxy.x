/**
 * The proxy manager service. Eventually, this module should be moved to the
 */
module proxy_manager.xqiz.it {
    package common import common.xqiz.it;

    package convert import convert.xtclang.org;
    package crypto  import crypto.xtclang.org;
    package web     import web.xtclang.org;

    import web.Uri;

    /**
     * Bootstrapping: configure and return the ProxyManager.
     */
    common.ProxyManager configure(Uri[] receivers) {
        ProxyManager mgr = new ProxyManager(receivers);
        return &mgr.maskAs(common.ProxyManager);
    }
}