import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import ecstasy.text.Log;

import web.HttpStatus;

import xenia.HttpHandler;
import xenia.HttpServer;
import xenia.HttpServer.Handler;
import xenia.HttpServer.RequestContext;

import common.model.WebAppInfo;


/**
 * AppHost for a Web module.
 */
service WebHost
        extends AppHost
        implements Handler {

    construct (HttpServer httpServer, ModuleRepository repository, WebAppInfo info,
               Directory homeDir, Directory buildDir) {
        construct AppHost(info.moduleName, homeDir);

        this.httpServer = httpServer;
        this.repository = repository;
        this.info       = info;
        this.buildDir   = buildDir;
    }

    /**
     * The HttpServer to use for communications.
     */
    HttpServer httpServer;

    /**
     * The module repository to use.
     */
    ModuleRepository repository;

    /**
     * The web application details.
     */
    WebAppInfo info;

    /**
     * The build directory.
     */
    Directory buildDir;

    /**
     * The AppHosts for the containers this module depends on.
     */
    AppHost[] dependencies = [];

    /**
     * The underlying HttpHandler.
     */
    HttpHandler? handler;

    /**
     * Indicates whether or not this WebHost is ready to handle HTTP requests.
     */
    Boolean active.get() = handler != Null;

    /**
     * Pending request counter.
     */
    @Atomic Int pendingRequests;

    /**
     * Total request counter (serves as an activity inidicator).
     */
    Int totalRequests;

    /**
     * The timer used to monitor the application activity.
     */
    @Inject Timer timer;

    /**
     * Indicates the number of attempted deactivations before forcefully killing the container.
     */
    Int deactivationProgress;

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
            errors.add($"Error: Module {moduleName.quoted} is not a WebApp");
            return False;
        }

        import xenia.tools.ModuleGenerator;

        ModuleGenerator generator = new ModuleGenerator(mainModule, $/_webModule.txt);
        if (ModuleTemplate webTemplate := generator.ensureWebModule(repository, buildDir, errors)) {
            Container container;
            if ((container, dependencies) :=
                    utils.createContainer(repository, webTemplate, homeDir, buildDir, False, errors)) {

                try {
                    Tuple result = container.invoke("createHandler_", Tuple:(httpServer));
                    HttpHandler handler = result[0].as(HttpHandler);
                    this.container = container;
                    this.handler   = handler;

                    // set the alarm, expecting at least one application request within next
                    // "check interval"
                    Int currentCount = totalRequests + 1;
                    timer.schedule(InactivityDuration, () -> checkActivity(currentCount));

                    return True, handler;
                } catch (Exception e) {
                    errors.add(e.toString());
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
     */
    void deactivate(Boolean explicit) {
        if (active) {
            // TODO: if deactivation is "implicit", should we force it in the same wat as for an
            //       implicit one?

            if (pendingRequests > 0 && ++deactivationProgress < DeactivationThreshold) {
                timer.schedule(Second, () -> deactivate(explicit));
                return;
            }

            // TODO: if deactivation is "explicit", we could prevent an implicit activation

            // TODO: pause, serialize and only then kill
            for (AppHost dependent : dependencies) {
                dependent.close();
            }
            container?.kill();

            dependencies         = [];
            handler              = Null;
            container            = Null;
            deactivationProgress = 0;
        }
    }


    // ----- Handler -------------------------------------------------------------------------------

    @Override
    void handle(RequestContext context, String uri, String method, Boolean tls) {
        if (deactivationProgress > 0) {
            // deactivation is in progress; would be nice to send back a corresponding page
            httpServer.send(context, HttpStatus.ServiceUnavailable.code, [], [], []);
            return;
        }

        HttpHandler handler;
        if (!(handler ?= this.handler)) {
            Log errors = new ErrorLog();

            if (!(handler := activate(False, errors))) {
                log($"Error: Failed to activate: {errors}");

                httpServer.send(context, HttpStatus.InternalServerError.code, [], [], []);
                return;
            }
        }

        pendingRequests++;
        totalRequests++;

        @Future Tuple result = handler.handle(context, uri, method, tls);

        &result.whenComplete((r, e) -> {pendingRequests--;});
    }


    // ----- Closeable -----------------------------------------------------------------------------

    @Override
    void close(Exception? e = Null) {
        for (AppHost dependent : dependencies) {
            dependent.close(e);
        }
        httpServer.close(e);

        super(e);
    }
}