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
service WebHost
        extends AppHost
        implements Handler {

    construct (HostInfo route, ModuleRepository repository, String account, WebAppInfo appInfo,
               CryptoPassword pwd, CatalogExtras extras, Directory homeDir, Directory buildDir) {
        construct AppHost(appInfo.moduleName, homeDir);

        this.route      = route;
        this.repository = repository;
        this.account    = account;
        this.appInfo    = appInfo;
        this.pwd        = pwd;
        this.extras     = extras;
        this.buildDir   = buildDir;
    }

    /**
     * The module repository to use.
     */
    ModuleRepository repository;

    /**
     * The account name this deployment belongs to.
     */
    String account;

    /**
     * The web application details.
     */
    WebAppInfo appInfo;

    /**
     * The password to use for the keystore.
     */
    CryptoPassword pwd;

    /**
     * A map of WebService classes for processing requests for the paths not handled by the web app
     * itself.
     *
     * @see [HttpHandler]
     */
    CatalogExtras extras;

    /**
     * The build directory.
     */
    Directory buildDir;

    /**
     * The AppHosts for the containers this module depends on.
     */
    AppHost[] dependencies = [];

    /**
     * The HostInfo that routes to this handler.
     */
    HostInfo route;

    /**
     * The underlying HttpHandler.
     */
    HttpHandler? handler;

    /**
     * The decryptor to be used by the underlying handler.
     */
    Decryptor? decryptor;

    /**
     * Indicates whether or not this WebHost is ready to handle HTTP requests.
     */
    Boolean active.get() = handler != Null;

    /**
     * Total request counter (serves as an activity indicator).
     */
    private Int totalRequests;

    /**
     * The timer used to monitor the application activity.
     */
    @Inject Timer timer;

    /**
     * Indicates the number of attempted deactivations before forcefully killing the container.
     */
    private Int deactivationProgress;

    /**
     * The number of seconds to wait for the application traffic to stop before killing it.
     */
    static Int DeactivationThreshold = 15;

    /**
     * The inactivity duration limit; if no requests come within that period, the application
     * will be deactivated.
     */
    static Duration InactivityDuration = Duration.ofSeconds(10);

    /*
     * Activate the underlying WebApp.
     *
     * @param explicit  True if the activation request comes from the platform management UI;
     *                  False if it's caused by an application HTTP request
     *
     * @return True iff the hosted WebApp is active
     */
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

        import tools.ModuleGenerator;

        ModuleGenerator generator = new ModuleGenerator(mainModule);
        if (ModuleTemplate webTemplate := generator.ensureWebModule(repository, buildDir, errors)) {
            Container container;
            if ((container, dependencies) := utils.createContainer(
                        repository, webTemplate, homeDir, buildDir, False, appInfo.injections, errors)) {

                try {
                    Tuple       result  = container.invoke("createHandler_", Tuple:(route, extras));
                    HttpHandler handler = result[0].as(HttpHandler);
                    handler.configure(decryptor? : assert as "Decryptor is missing");

                    this.container = container;
                    this.handler   = handler;

                    // set the alarm, expecting at least one application request within next
                    // "check interval"
                    Int currentCount = totalRequests + 1;
                    timer.schedule(InactivityDuration, () -> checkActivity(currentCount));

                    return True, handler;
                } catch (Exception e) {
                    errors.add(e.message);
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
            timer.schedule(InactivityDuration, () -> checkActivity(currentCount));
        }
    }

    /*
     * Deactivate the underlying WebApp.
     *
     * @param explicit  True if the deactivation request comes from the platform management UI;
     *                  False if it's caused by the [activity check](checkActivity)
     *
     * @return True iff the deactivation has succeeded; False if it has been re-scheduled
     */
    Boolean deactivate(Boolean explicit) {
        if (HttpHandler handler ?= this.handler) {
            // TODO: if deactivation is "implicit", we need to "serialize to disk" rather than "shutdown"

            if (!handler.shutdown() && ++deactivationProgress < DeactivationThreshold) {
                timer.schedule(Second, () -> deactivate(explicit));
                return False;
            }

            // TODO: if deactivation is "explicit", we could prevent an implicit activation

            // TODO: pause, serialize and only then kill
            for (AppHost dependent : dependencies) {
                dependent.close();
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
                log($"Error: Failed to activate: {errors}");

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