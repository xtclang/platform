import ecstasy.mgmt.Container;

import ecstasy.text.Log;

import model.AppInfo;

/**
 * A host for an application module.
 */
@Abstract
class AppHost(String moduleName, AppInfo? appInfo, Directory homeDir, Directory buildDir)
        implements Closeable {
    /**
     * The Container that hosts the module; always 'Null' for child hosts.
     */
    public/protected Container? container;

    /**
     * The hosted module name.
     */
    public/protected String moduleName;

    /**
     * The application details. Can be `Null` if the host is not a root, but a child of another host.
     */
    AppInfo? appInfo;

    /**
     * The home directory.
     */
    public/protected Directory homeDir;

    /**
     * The build directory for auto-generated artifacts.
     */
    public/protected Directory buildDir;

    /**
     * Indicates whether or not this host is ready to handle corresponding requests or needs to be
     * activated first.
     *
     * Unlike the `autoStart` property of the [AppInfo], which indicates that an application needs
     * to be loaded automatically, this property indicates whether or not the app is currently
     * "in memory".
     */
    @RO Boolean active;

    /**
     * A transient flag that indicates whether or not there are some changes in the AppInfo that
     * would take effect only after the application is re-started.
     */
    Boolean restartRequired;

    /**
     * Log the specified message to the application "console" file.
     */
    void log(String message) {
        @Inject Clock clock;

        homeDir.fileFor("console.log").ensure().append($"\n{clock.now}: {message}".utf8());
    }

    /**
     * Activate the underlying app.
     *
     * @param explicit  True iff the activation request comes from the platform management UI
     *
     * @return a host specific object
     */
    conditional Object activate(Boolean explicit, Log errors);

    /*
     * Deactivate the underlying app.
     *
     * @param explicit  True if the deactivation request comes from the platform management UI;
     *                  False if it's caused by the application activity check
     *
     * @return True iff the deactivation has succeeded; False if it has been re-scheduled
     */
    Boolean deactivate(Boolean explicit);

    @Override
    String toString() {
        if (AppInfo appInfo ?= this.appInfo) {
            return $"{appInfo.deployment.quoted()}; {active=}";
        } else {
            return $"Embedded {moduleName.quoted()} module";
        }
    }


    // ----- Closeable -----------------------------------------------------------------------------

    @Override
    void close(Exception? e = Null) {
        container?.kill();
    }
}