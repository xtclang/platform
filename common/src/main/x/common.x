/**
 * The module for all platform APIs.
 */
module common.xqiz.it
    {
    package web import web.xtclang.org;

    import ecstasy.text.SimpleLog;

    /**
     * A Log as a service.
     */
    service ErrorLog
            extends SimpleLog
        {
        void reportAll(function void (String) report)
            {
            for (String msg : messages)
                {
                report(msg);
                }
            }
        }
    }