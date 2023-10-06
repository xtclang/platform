import ecstasy.mgmt.Container;

import common.model.WebAppInfo;


/**
 * AppHost for a Web module.
 */
const WebHost
        extends AppHost {

    construct (Container container, WebAppInfo info, Directory homeDir,
               function void() shutdown, AppHost[] dependencies) {
        construct AppHost(info.moduleName, homeDir);

        this.container    = container;
        this.info         = info;
        this.shutdown     = shutdown;
        this.dependencies = dependencies;
    }

    /**
     * The web application details.
     */
    WebAppInfo info;

    /**
     * The function that would shutdown the HTTP server for this module.
     */
    function void() shutdown;

    /**
     * The AppHosts for the containers this module depends on.
     */
    AppHost[] dependencies;


    // ----- Closeable -----------------------------------------------------------------------------

    @Override
    void close(Exception? e = Null) {
        for (AppHost dependent : dependencies) {
            dependent.close(e);
        }
        shutdown();

        super(e);
    }
}