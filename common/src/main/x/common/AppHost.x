import ecstasy.mgmt.Container;


/**
 * A host for an application module.
 */
class AppHost(String moduleName, Directory homeDir)
        implements Closeable {
    /**
     * The Container that hosts the module.
     */
    Container? container;

    /**
     * The hosted module name.
     */
    public/protected String moduleName;

    /**
     * The home directory.
     */
    public/protected Directory homeDir;

    /**
     * Log the specified message to the application "console" file.
     */
    void log(String message) {
        homeDir.fileFor("console.log").ensure().append(utils.NewLine).append(message.utf8());
    }


    // ----- Closeable -----------------------------------------------------------------------------

    @Override
    void close(Exception? e = Null) {
        container?.kill();
    }
}