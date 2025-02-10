import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import ecstasy.text.Log;

import crypto.CryptoPassword;
import crypto.Decryptor;

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
service WebHost(HostInfo route, String account, ModuleRepository repository, WebAppInfo appInfo,
                CryptoPassword pwd, Map<String, DbHost> sharedDbHosts, WebApp challengeApp,
                CatalogExtras extras, Directory homeDir, Directory buildDir)
        extends AppHost(appInfo.moduleName, appInfo, homeDir, buildDir)
        implements Handler {

    @Override
    WebAppInfo appInfo.get() = super().as(WebAppInfo);

    @Override
    Boolean active.get() = handler != Null;

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
     * The HttpHandler used only to process ACME challenge requests while the application is
     * inactive.
     */
    protected HttpHandler? challengeHandler;

    /**
     * The decryptor to be used by the underlying handler.
     */
    protected Decryptor? decryptor;

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

        if (ModuleTemplate webTemplate := new tools.ModuleGenerator(mainModule).
                ensureWebModule(repository, buildDir, errors)) {

            if ((Container container, dependencies) :=
                    utils.createContainer(repository, webTemplate, this, errors)) {
                try {
                    Tuple       result  = container.invoke("createHandler_", Tuple:(route, extras));
                    HttpHandler handler = result[0].as(HttpHandler);
                    handler.configure(decryptor? : assert as "Decryptor is missing");

                    this.container = container;
                    this.handler   = handler;

                    // if a challengeHandler has been activated, close and drop it
                    challengeHandler?.close^();
                    challengeHandler = Null;

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
            deferredRequests.forEach(request -> // handle^(request));
            {
            handle^(request);
            });
        } else {
            errors.reportAll(log);
            deferredRequests.forEach(request ->
                    request.respond(HttpStatus.InternalServerError.code, [], [], []));
        }
    }

    // ----- Handler interface ---------------------------------------------------------------------

    /**
     * This method is duck-typed into the Handler to support cookie encryption.
     */
    void configure(Decryptor decryptor) {
        this.decryptor = decryptor;
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
                request.respond(HttpStatus.InternalServerError.code, [], [], []);
                return;
            }
        }

        totalRequests++;
        pendingRequests++;

        request.observe((_) -> {--pendingRequests;});
        handler.handle^(request);
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