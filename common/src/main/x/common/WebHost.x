import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import ecstasy.text.Log;

import crypto.CryptoPassword;
import crypto.Decryptor;

import metrics.TimeSeries;

import web.HttpStatus;
import web.WebApp;

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
service WebHost(HostInfo route, String account, ModuleRepository repository,
                WebAppInfo appInfo, Directory homeDir, Directory buildDir,
                Map<String, DbHost> sharedDbHosts, WebApp challengeApp, CatalogExtras extras,
                Decryptor secretsDecryptor, function void(WebAppInfo) addStubRoute
                )
        extends AppHost(appInfo.moduleName, appInfo, homeDir, buildDir)
        implements Handler {

    @Inject Clock clock;

    @Override
    WebAppInfo appInfo.get() = super().as(WebAppInfo);

    @Override
    Boolean active.get() = handler != Null;

    /**
     * The HostInfo that routes to this handler.
     */
    protected HostInfo route;

    /**
     * The account name this deployment belongs to.
     */
    public/protected String account;

    /**
     * The module repository to use.
     */
    protected ModuleRepository repository;

    /**
     * A Map of shared DBHosts keyed by their deployment names.
     */
    protected Map<String, DbHost> sharedDbHosts;

    /**
     * The challenge WebApp, which is used to serve ACME challenge requests when a deployments have
     * been registered, but either not yet deployed or deactivated.
     */
    protected WebApp challengeApp;

    /**
     * A map of WebService classes for processing requests for the paths not handled by the web app
     * itself.
     *
     * @see [HttpHandler]
     */
    protected CatalogExtras extras;

    /**
     * The decryptor to use for decrypting application secrets.
     */
    public/protected Decryptor secretsDecryptor;

    /**
     * The function that is responsible for adding a stub route for this deployment.
     */
    public/protected function void(WebAppInfo) addStubRoute;

    /**
     * The AppHosts for the containers this module depends on.
     */
    protected AppHost[] dependencies = [];

    /**
     * The underlying HttpHandler.
     */
    protected HttpHandler? handler;

    /**
     * The HttpHandler used only to process ACME challenge requests while the application is
     * inactive.
     */
    protected HttpHandler? challengeHandler;

    /**
     * The decryptor to be used by the underlying handler.
     */
    protected Decryptor? cookieDecryptor;

    /**
     * Total request counter (serves as an activity indicator).
     */
    public/protected Int totalRequests;

    /**
     * Pending request counter.
     */
    protected Int pendingRequests;

    /**
     * Pause indicator; a paused host
     */
    protected Boolean paused;

    /**
     * Requests that came while the WebHost was paused.
     */
    protected RequestInfo[] deferredRequests = [];

    /**
     * The maximum number of deferred requests.
     */
    static Int MaxDeferredRequests = 50;

    // ----- statistics ----------------------------------------------------------------------------

    /**
     * The base frequency of all statistics collection. The collection frequency for a specific stat
     * should be a factor of the base frequency.
     */
    static Duration StatsInterval = ofSeconds(10);

    /**
     * The request info is collected every minute with hourly fidelity and a 60-day retention
     * window.
     *
     * The total cost is 24*60 = 1,440 UInt32 values ~ 6KB
     */
    TimeSeries<UInt32> requestStats = new TimeSeries(Hour, ofDays(60));

    /**
     * The epoch-aligned hour currently being collected.
     */
    private Int requestStatsHour = -1;

    /**
     * The running request count for [requestStatsHour].
     */
    private UInt32 requestStatsHourCount = 0;

    /**
     * The `totalRequests` value at the previous statistics refresh.
     */
    private Int requestStatsLastCount = 0;

    /**
     * The frequency of the request collection; collected every minute (every 6th base cycle).
     */
    static Int RequestRate = 60/10;

    /**
     * The mutually exclusive states used to account for the WebHost lifetime.
     */
    private enum RuntimeState {Active, Chilled, Frozen}

    /**
     * The current runtime state. State accounting starts with the first successful activation.
     */
    private RuntimeState runtimeState = Frozen;

    /**
     * The start of the current runtime state, or Null before the first activation.
     */
    private Time? runtimeStateSince;

    /**
     * Accumulated time spent processing one or more requests.
     */
    private Duration activeTime = None;

    /**
     * Accumulated time spent loaded in memory without processing a request.
     */
    private Duration chilledTime = None;

    /**
     * Accumulated time spent off-loaded after the first activation.
     */
    private Duration frozenTime = None;

    /**
     * The number of transitions from frozen to chilled, excluding the initial activation.
     */
    private Int wakeCount;

    // ----- AppHost methods -----------------------------------------------------------------------

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

        if (ModuleTemplate webTemplate := new tools.ModuleGenerator(mainModule, appInfo).
                ensureWebModule(repository, buildDir, errors)) {

            if ((Container container, dependencies) :=
                    utils.createContainer(repository, webTemplate, this, errors)) {
                try {
                    Tuple       result  = container.invoke("createHandler_", Tuple:(route, extras));
                    HttpHandler handler = result[0].as(HttpHandler);
                    handler.configure(cookieDecryptor? : assert as "Cookie decryptor is missing");

                    this.container = container;
                    this.handler   = handler;
                    transitionState(Chilled);

                    // if a challengeHandler has been activated, close and drop it
                    challengeHandler?.close^();
                    challengeHandler = Null;

                    clock.schedule(StatsInterval, &collectStats(0));

                    return True, handler;
                } catch (Exception e) {
                    errors.add($"Error: Failed to create a container; {e.message}");
                    container.kill();
                }
            }
        } else {
            errors.add($"Error: Failed to create a WebModule for moduleName.quoted()}");
        }
        return False;
    }

    @Override
    Boolean deactivate(Boolean explicit) {
        if (HttpHandler handler ?= this.handler) {
            handler.close(); // clean up downstream
            this.handler = Null;

            if (!explicit) {
                paused = True;

                if (pendingRequests > 0) {
                    // we need to give the app some time to finish up the current requests;
                    // it's a responsibility of the HostManager to repeat deactivation
                    return False;
                }
            }
            unload(explicit);
        } else if (paused && (explicit || pendingRequests == 0)) {
            unload(explicit);
        }
        transitionState(Frozen);
        return True;

        void unload(Boolean explicit) {
            for (AppHost dependent : dependencies) {
                dependent.deactivate(False);
            }
            if (!explicit) {
                // TODO: container.pause(); container.store();
            }

            container?.kill();

            dependencies = [];
            container    = Null;
        }
    }

    // ----- "pausing" support ---------------------------------------------------------------------

    /**
     * Defer a request that came while the WebHost was paused.
     *
     * @return True if the request is deferred; False otherwise
     */
    Boolean deferRequest(RequestInfo request) {
        RequestInfo[] deferredRequests = this.deferredRequests;
        Int           deferredCount    = deferredRequests.size;
        if (deferredCount == 0) {
            deferredRequests      = new RequestInfo[]; // mutable
            this.deferredRequests = deferredRequests;
        } else if (deferredCount > MaxDeferredRequests) {
            return False;
        }
        deferredRequests += request;
        return True;
    }

    /**
     * Resume a paused WebHost.
     */
    void resume() {
        if (!paused) {
            return;
        }
        paused = False;

        RequestInfo[] deferredRequests = this.deferredRequests;
        if (deferredRequests.empty) {
            // no need to activate
            return;
        }
        this.deferredRequests = [];

        Log errors = new ErrorLog();
        if (activate(False, errors)) {
            deferredRequests.forEach(request -> handle^(request));
        } else {
            errors.reportAll(log);
            deferredRequests.forEach(request ->
                    request.respond(HttpStatus.InternalServerError.code, [], [],
                                    errors.collectErrors().utf8()));
        }
    }

    // ----- Handler interface ---------------------------------------------------------------------

    /**
     * This method is duck-typed into the Handler to support cookie encryption.
     */
    void configure(Decryptor decryptor) {
        this.cookieDecryptor = decryptor;
    }

    @Override
    void handle(RequestInfo request) {
        HttpHandler handler;
        if (!(handler ?= this.handler)) {
            if (request.uriString.startsWith("/.well-known/acme-challenge")) {
                // this is a certificate challenge request; no need to load the app
                if (!(handler ?= challengeHandler)) {
                    handler          = new HttpHandler(route, challengeApp, extras);
                    challengeHandler = handler;
                }
                handler.handle^(request);
                return;
            }

            if (paused) {
                if (!deferRequest(request)) {
                    request.respond(HttpStatus.TooManyRequests.code, [], [], []);
                }
                return;
            }

            Log errors = new ErrorLog();
            if (!(handler := activate(False, errors))) {
                errors.reportAll(log);
                request.respond(HttpStatus.InternalServerError.code, [], [],
                                errors.collectErrors().utf8());
                return;
            }
        }

        totalRequests++;
        pendingRequests++;
        transitionState(Active);

        request.observe(_ -> {
            // a forced deactivation may have already transitioned the host to "Frozen"
            if (--pendingRequests == 0 && runtimeState == Active) {
                transitionState(Chilled);
            }
        });
        handler.handle^(request);
    }

    // ----- Statistics support --------------------------------------------------------------------

    /**
     * @param collectCount  the monotonic counter of consecutive invocations
     */
    void collectStats(Int collectCount) {
        if (collectCount % RequestRate == 0) {
            refreshRequestStats();
        }

        if (active) {
            clock.schedule(StatsInterval, &collectStats(collectCount+1));
        }
    }

    /**
     * Refresh the current hourly request count.
     */
    private void refreshRequestStats() {
        Time   now      = clock.now;
        Int    hour     = (now.epochPicos / Duration.PicosPerHour).toInt64();
        UInt32 newCount = (totalRequests - requestStatsLastCount).toUInt32();

        if (hour == requestStatsHour) {
            requestStatsHourCount += newCount;
        } else {
            requestStatsHour      = hour;
            requestStatsHourCount = newCount;
        }

        // replaces its running total ("now" maps to the current hourly bucket)
        requestStats.add(now, requestStatsHourCount);
        requestStatsLastCount = totalRequests;
    }

    /**
     * Collect the request count stats.
     *
     * return the array of request numbers from the TimeSeries
     * return the timestamp of the oldest sample
     */
    (immutable UInt32[] counts, Time endTime) queryRequests(Duration rate, Int limit) {
        refreshRequestStats();
        return requestStats.query(rate, limit,
                                  rate == requestStats.resolution ? Null : new agg.Sum<UInt32>());
    }

    /**
     * Obtain a snapshot of the runtime state totals.
     *
     * Concurrent requests form a single active interval, so active, chilled, and frozen always
     * partition the elapsed time since the first successful activation.
     *
     * @return the number of seconds spent processing requests
     * @return the number of seconds spent loaded but idle
     * @return the number of seconds spent off-loaded
     * @return the number of transitions from frozen to chilled
     */
    (Int active, Int chilled, Int frozen, Int wakes) queryState() {
        Duration active   = activeTime;
        Duration chilled  = chilledTime;
        Duration frozen   = frozenTime;
        Time     now      = clock.now;

        if (Time since ?= runtimeStateSince) {
            Duration elapsed = now - since;
            switch (runtimeState) {
            case Active:
                active += elapsed;
                break;
            case Chilled:
                chilled += elapsed;
                break;
            case Frozen:
                frozen += elapsed;
                break;
            }
        }

        return active.seconds, chilled.seconds, frozen.seconds, wakeCount;
    }

    /**
     * Complete the current runtime interval and enter the specified state.
     */
    private void transitionState(RuntimeState nextState) {
        Time now = clock.now;
        if (Time since ?= runtimeStateSince) {
            if (nextState == runtimeState) {
                return;
            }

            Duration elapsed = now - since;
            switch (runtimeState) {
            case Active:
                activeTime += elapsed;
                break;
            case Chilled:
                chilledTime += elapsed;
                break;
            case Frozen:
                frozenTime += elapsed;
                break;
            }

            if (runtimeState == Frozen && nextState == Chilled) {
                ++wakeCount;
            }
        }

        runtimeState      = nextState;
        runtimeStateSince = now;
    }

    // ----- Helper methods ------------------------------------------------------------------------

    /**
     * Find a shared DbHost for the specified name
     */
    conditional DbHost findSharedDbHost(String dbModuleName) = sharedDbHosts.get(dbModuleName);

    // ----- Closeable -----------------------------------------------------------------------------

    @Override
    void close(Exception? e = Null) {
        deactivate(True);
    }
}
