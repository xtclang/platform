/**
 * The module for all platform APIs.
 */
module common.xqiz.it {
    package conv    import convert.xtclang.org;
    package crypto  import crypto.xtclang.org;
    package jsondb  import jsondb.xtclang.org;
    package oodb    import oodb.xtclang.org;
    package sec     import sec.xtclang.org;
    package web     import web.xtclang.org;
    package webauth import webauth.xtclang.org;
    package xenia   import xenia.xtclang.org;

    package platformAuth import auth.xqiz.it;

    import ecstasy.text.SimpleLog;

    typedef function void (String) as Reporting;

    /**
     * A Log as a service.
     */
    service ErrorLog
            extends SimpleLog {

        void reportAll(Reporting report) {
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

    /**
     * Create a fixed length string with the specified (or current) time.
     */
    static String logTime(Time? time = Null) {
        if (time == Null) {
            @Inject Clock clock;
            time = clock.now;
        }

        return appendLogTime(new StringBuffer(23), time).toString();
    }

    /**
     * Append the specified (or current) time into the buffer as a fixed length string.
     *
     * This helper exists to be used within Ecstasy template strings, e.g.
     *
     *     $"{common.logTime($)} ..."
     */
    static String logTime(Appender<Char> buf, Time? time = Null) {
        appendLogTime(buf, time);
        return "";
    }

    /**
     * Append the specified (or current) time to the buffer as a fixed length string.
     */
    static Appender<Char> appendLogTime(Appender<Char> buf, Time? time = Null) {
        if (time == Null) {
            @Inject Clock clock;
            time = clock.now;
        }

        time.date.appendTo(buf);
        buf.add(' ');
        val tod = time.timeOfDay;

        Int hour = tod.hour;
        if (hour < 10) {
            buf.add('0');
        }
        hour.appendTo(buf);
        buf.add(':');

        Int minute = tod.minute;
        if (minute < 10) {
            buf.add('0');
        }
        minute.appendTo(buf);
        buf.add(':');

        Int second = tod.second;
        if (second < 10) {
            buf.add('0');
        }
        second.appendTo(buf);

        buf.add('.');
        Int ms = tod.milliseconds;
        if (ms < 100) {
            buf.add('0');
            if (ms < 10) {
                buf.add('0');
            }
        }
        ms.appendTo(buf);

        return buf;
    }
}