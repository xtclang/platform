/**
 * The module for all platform APIs.
 */
module common.xqiz.it {
    package crypto import crypto.xtclang.org;
    package jsondb import jsondb.xtclang.org;
    package oodb   import oodb.xtclang.org;
    package web    import web.xtclang.org;
    package xenia  import xenia.xtclang.org;

    import ecstasy.text.SimpleLog;

    /**
     * A Log as a service.
     */
    service ErrorLog
            extends SimpleLog {

        void reportAll(function void (String) report) {
            for (String msg : messages) {
                report(msg);
            }
        }

        String collectErrors() {
            StringBuffer buf = new StringBuffer();
            for (String message : messages) {
                if (message.startsWith("Error:")) {
                    buf.append(message)
                       .append("\n");
                }
            }
            return buf.toString();
        }
    }
}