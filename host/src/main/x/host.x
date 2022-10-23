/**
 * The platform host service.
 */
module host.xqiz.it
    {
    package common import common.xqiz.it;
    package xenia  import xenia.xtclang.org;

    /**
     * Bootstrapping: configure and return the HostManager.
     */
    common.HostManager configure()
        {
        HostManager mgr = new HostManager();
        return &mgr.maskAs(common.HostManager); // TODO GG: should masking be done automatically by "invoke"?
        }
    }