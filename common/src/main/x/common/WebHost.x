import ecstasy.mgmt.Container;

/**
 * AppHost for a Web module.
 */
const WebHost
        extends AppHost
    {
    construct (Container container, String moduleName, Directory homeDir, String domain,
               function void() shutdown, AppHost[] dependents)
        {
        construct AppHost(moduleName, homeDir);

        this.container  = container;
        this.domain     = domain;
        this.shutdown   = shutdown;
        this.dependents = dependents;
        }

    /**
     * The application domain.
     */
    String domain;

    /**
     * The function that would shutdown the HTTP server for this module.
     */
    function void() shutdown;

    /**
     * The AppHosts for the containers this module depends on.
     */
    AppHost[] dependents;


    // ----- Closeable -----------------------------------------------------------------------------

    @Override
    void close(Exception? e = Null)
        {
        for (AppHost dependent : dependents)
            {
            dependent.close(e);
            }
        shutdown();
        }
    }