import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import ecstasy.text.Log;

import crypto.CryptoPassword;
import crypto.Decryptor;

import web.HttpStatus;

import web.http.HostInfo;

import xenia.HttpHandler;
import xenia.HttpHandler.CatalogExtras;
import xenia.HttpServer;
import xenia.HttpServer.Handler;
import xenia.HttpServer.RequestInfo;

import common.model.WebAppInfo;


/**
 * AppHost for a Web module.
 */
service WebHost(HostManager hostManager, HostInfo route, String account, ModuleRepository repository,
                WebAppInfo appInfo, CryptoPassword pwd, CatalogExtras extras, Directory homeDir,
                Directory buildDir)
        extends AppHost(appInfo.moduleName, appInfo, homeDir)
        implements Handler {

    @Override
    WebAppInfo appInfo.get() = super().as(WebAppInfo);

    @Override
    Boolean active.get() = handler != Null;

    /**
     * The HostManager instance.
     */
    protected HostManager hostManager;

    /**
     * The account name this deployment belongs to.
     */
    public/protected String account;

    /**
     * The module repository to use.
     */
    protected ModuleRepository repository;

    /**
     * The password to use for the keystore.
     */
    public/protected CryptoPassword pwd;

    /**
     * A map of WebService classes for processing requests for the paths not handled by the web app
     * itself.
     *
     * @see [HttpHandler]
     */
    protected CatalogExtras extras;

    /**
     * The build directory.
     */
    protected Directory buildDir;

    /**
     * The AppHosts for the containers this module depends on.
     */
    AppHost[] dependencies = [];

    /**
     * The HostInfo that routes to this handler.
     */
    protected HostInfo route;

    /**
     * The underlying HttpHandler.
     */
    protected HttpHandler? handler;

    /**
     * The decryptor to be used by the underlying handler.
     */
    protected Decryptor? decryptor;

    /**
     * Total request counter (serves as an activity indicator).
     */
    public/private Int totalRequests;

    /**
     * The clock used to monitor the application activity.
     */
    @Inject Clock clock;

    /**
     * Activity check cancellation function.
     */
    private Clock.Cancellable? cancelActivityCheck;

    /**
     * Indicates the number of attempted deactivations before forcefully killing the container.
     */
    private Int deactivationProgress;

    /**
     * The inactivity duration limit; if no requests come within that period, the application
     * will be deactivated.
     */
    static Duration InactivityDuration = Duration.ofSeconds(20);

    /*
     * Activate the underlying WebApp.
     *
     * @param explicit  True if the activation request comes from the platform management UI;
     *                  False if it's caused by an application HTTP request
     *
     * @return True iff the hosted WebApp is active
     * @return (conditional) the corresponding HttpHandler
     */
    @Override
    conditional HttpHandler activate(Boolean explicit, Log errors) {
        if (HttpHandler handler ?= this.handler) {
            return True, handler;
        }

        ModuleTemplate mainModule;
        try {
            // we need the resolved module to look up annotations
            mainModule = repository.getResolvedModule(moduleName);
        } catch (Exception e) {
            errors.add($"Error: Failed to resolve module: {moduleName.quoted()}: {e.message}");
            return False;
        }

        String moduleName = mainModule.qualifiedName;
        if (!utils.isWebModule(mainModule)) {
            errors.add($"Error: Module {moduleName.quoted()} is not a WebApp");
            return False;
        }

        // check if all the shared databases are deployed
        Map<String, DbHost> sharedDbHosts;
        if (appInfo.sharedDBs.empty) {
            sharedDbHosts = [];
        } else {
            sharedDbHosts = new ListMap();
            for (String dbDeployment : appInfo.sharedDBs) {
                if (DbHost dbHost := hostManager.getDbHost(dbDeployment)) {
                    String dbModuleName = dbHost.moduleName;
                    if (sharedDbHosts.contains(dbModuleName)) {
                        errors.add($|Error: More than one dependency on the same database module \
                                    |"{dbModuleName}"
                                   );
                        return False;
                    } else {
                        sharedDbHosts.put(dbModuleName, dbHost);
                    }
                } else {
                    errors.add($"Error: Dependent database {dbDeployment.quoted()} has not been deployed");
                    return False;
                }
            }
        }

        if (ModuleTemplate webTemplate := new tools.ModuleGenerator(mainModule).
                ensureWebModule(repository, buildDir, errors)) {

            if ((Container container, dependencies) := utils.createContainer(repository, webTemplate,
                        homeDir, buildDir, False, appInfo.injections, sharedDbHosts.get, errors)) {
                try {
                    Tuple       result  = container.invoke("createHandler_", Tuple:(route, extras));
                    HttpHandler handler = result[0].as(HttpHandler);
                    handler.configure(decryptor? : assert as "Decryptor is missing");

                    this.container = container;
                    this.handler   = handler;

                    // set the alarm, expecting at least one application request within next
                    // "check interval"
                    Int      currentCount = totalRequests + 1;
                    Duration duration     = InactivityDuration;
                    if (explicit) {
                        // they explicitly started it; keep it up longer first time around
                        duration = duration*2;
                    }
                    cancelActivityCheck =
                        clock.schedule(duration, () -> checkActivity(currentCount));

                    return True, handler;
                } catch (Exception e) {
                    errors.add($"Error: Failed to create a container; {e}");
                    container.kill();
                }
            }
        } else {
            errors.add($"Error: Failed to create a WebModule for moduleName.quoted()}");
        }
        return False;
    }

    void checkActivity(Int prevRequests) {
        if (totalRequests <= prevRequests) {
            // no activity since the last check; deactivate the handler
            deactivate(False);
        } else {
            // some activity detected; reschedule the check
            Int currentCount = totalRequests;
            cancelActivityCheck =
                clock.schedule(InactivityDuration, () -> checkActivity(currentCount));
        }
    }

    @Override
    Boolean deactivate(Boolean explicit) {
        if (HttpHandler handler ?= this.handler) {

            cancelActivityCheck?();
            handler.close();

            if (!explicit) {
                // TODO: container.pause(); container.store();
            }

            for (AppHost dependent : dependencies) {
                dependent.deactivate(explicit);
            }
            container?.kill();

            this.dependencies         = [];
            this.handler              = Null;
            this.container            = Null;
            this.deactivationProgress = 0;
        }
        return True;
    }


    // ----- Handler -------------------------------------------------------------------------------

    /**
     * This method is duck-typed into the Handler to support cookie encryption.
     */
    void configure(Decryptor decryptor) {
        this.decryptor = decryptor;
    }

    @Override
    void handle(RequestInfo request) {
        if (deactivationProgress > 0) {
            // deactivation is in progress; would be nice to send back a corresponding page
            request.respond(HttpStatus.ServiceUnavailable.code, [], [], []);
            return;
        }

        HttpHandler handler;
        if (!(handler ?= this.handler)) {
            Log errors = new ErrorLog();

            if (!(handler := activate(False, errors))) {
                errors.reportAll(log);

                request.respond(HttpStatus.InternalServerError.code, [], [], []);
                return;
            }
        }

        totalRequests++;

        handler.handle^(request);
    }


    // ----- Closeable -----------------------------------------------------------------------------

    @Override
    void close(Exception? e = Null) {
        for (AppHost dependent : dependencies) {
            dependent.close(e);
        }

        super(e);
    }
}