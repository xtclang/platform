import web.Session;

/**
 * Session mixin that is automatically incorporated into a Session implementation.
 */
mixin SessionData
        into Session {

    String? accountName;
}
