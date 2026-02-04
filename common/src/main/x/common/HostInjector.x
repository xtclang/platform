import ecstasy.lang.src.Compiler;

import ecstasy.annotations.Inject;

import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.ResourceProvider;

import crypto.Algorithms;
import crypto.KeyStore;

import web.Client;
import web.HttpClient;
import web.WebApp;
import web.WebService;

import web.sessions.Broker;

import model.AppInfo;
import model.IdpInfo;
import model.InjectionKey;
import model.WebAppInfo;

/**
 * The ResourceProvider used for hosted containers.
 */
service HostInjector(AppHost appHost)
        implements ResourceProvider {
    /**
     * The AppHost that represents the hosted container.
     */
    protected AppHost appHost;

    /**
     * The hosted container.
     *
     * Quite naturally, there is a catch-22: we need an injector to instantiate a container, so this
     * value can get provided only after the container is created.
     */
    @Unassigned Container hostedContainer;

    /**
     * Indicator of a kernel module.
     */
    Boolean platform.get() = appHost.is(KernelHost);

    /**
     * The [FileStore] allocated for the hosted container.
     */
    @Lazy FileStore store.calc() = new ecstasy.fs.DirectoryFileStore(appHost.homeDir);

    /**
     * The [Console] for the hosted container.
     */
    @Lazy ConsoleImpl consoleImpl.calc() {
        File consoleFile = appHost.homeDir.fileFor("console.log");
        if (consoleFile.exists) {
            // remove the old content
            consoleFile.truncate(0);
        } else {
            consoleFile.ensure();
        }
        return new ConsoleImpl(consoleFile);
    }

    /**
     * The file-based Console implementation.
     */
    class ConsoleImpl(File consoleFile)
            implements Console {

        @Inject Clock clock;
        private Boolean addTimestamp = True;

        @Override
        void print(Object o = "", Boolean suppressNewline = False) {
            String message;
            switch (addTimestamp, suppressNewline) {
            case (True, False):
                message = $"{clock.now}: {o}\n";
                break;

            case (True, True):
                message = $"{clock.now}: {o}";
                addTimestamp = False;
                break;

            case (False, False):
                message = $"{o}\n";
                addTimestamp = True;
                break;

            case (False, True):
                message = o.toString();
                break;
            }
            consoleFile.append(message.utf8());
        }

        @Override
        String readLine(String prompt = "", Boolean suppressEcho = False) = throw new Unsupported();
    }

    @Override
    Supplier getResource(Type type, String name) {
        import Container.Linker;

        switch (type, name) {
        case (Console, "console"):
            if (platform) {
                @Inject Console console;
                return console;
            }
            return &consoleImpl.maskAs(Console);

        case (Clock, "clock"):
            @Inject Clock clock;
            return clock;

        case (Timer, "timer"):
            return (Inject.Options opts) -> {
                @Inject(opts=opts) Timer timer;
                return timer;
            };

        case (FileStore, "storage"):
            if (platform) {
                @Inject FileStore storage;
                return storage;
            }
            return &store.maskAs(FileStore);

        case (Directory, _):
            switch (name) {
            case "rootDir":
                if (platform) {
                    @Inject Directory rootDir;
                    return rootDir;
                }

                Directory root = store.root;
                return &root.maskAs(Directory);

            case "homeDir":
                if (platform) {
                    @Inject Directory homeDir;
                    return homeDir;
                }

                Directory root = store.root;
                return &root.maskAs(Directory);

            case "curDir":
                if (platform) {
                    @Inject Directory curDir;
                    return curDir;
                }

                Directory root = store.root;
                return &root.maskAs(Directory);

            case "tmpDir":
                if (platform) {
                    @Inject Directory tmpDir;
                    return tmpDir;
                }

                Directory temp = store.root.dirFor("_temp").ensure();
                return &temp.maskAs(Directory);

            default:
                throw new Exception($"Invalid Directory resource: \"{name}\"");
            }

        case (Random, "random"):
        case (Random, "rnd"):
            return (Inject.Options opts) -> {
                @Inject(opts=opts) Random random;
                return random;
            };

        case (Compiler, "compiler"):
            @Inject Compiler compiler;
            return compiler;

        case (Linker, "linker"):
            @Inject Linker linker;
            return linker;

        case (ModuleRepository, "repository"):
            @Inject ModuleRepository repository;
            return repository;

        case (Algorithms, "algorithms"):
            return (Inject.Options opts) -> {
                @Inject(opts=opts) Algorithms algorithms;
                return algorithms;
            };

        case (KeyStore, "keystore"):
            return (Inject.Options opts) -> {
                @Inject(opts=opts) KeyStore keystore;
                return keystore;
            };

        case (Broker?, "sessionBroker"):
            return (Inject.Options opts) -> {
                WebApp webApp;
                if (platform) {
                    // platformUI (WebApp) uses CookieBroker
                    if (webApp := hostedContainer.innerTypeSystem.primaryModule.is(WebApp)) {
                    } else {
                        return Null;
                    }
                } else {
                    if (appHost.appInfo.is(WebAppInfo)?.useCookies) {
                        // main module is a wrapper (see _webModule.txt resource)
                        webApp = hostedContainer.invoke("hostedWebApp_")[0].as(WebApp);
                    } else {
                        return Null;
                    }
                }

                val broker = new xenia.CookieBroker(webApp);
                return &broker.maskAs(Broker+WebService.ExtrasAware);
            };

        case (Client, "client"):
            private @Lazy Client client.calc() {
                Client client = new HttpClient();
                if (!platform) {
                    // TODO GG: create a RestrictedClient (maybe based on the appInfo), only allowing
                    //          access to well known OAuth authorization servers (e.g. github)
                }
                return client;
            }
            return &client.maskAs(Client);

        case (String, "clientId"):
        case (String, "clientSecret"):
            if (platform) {
                // TODO GG: extract platform secrets from the KernelHost
                return (Inject.Options opts) -> assert;
            }
            return (Inject.Options opts) -> {
                assert String  provider := opts.is(String),
                       WebHost webHost  := appHost.is(WebHost);
                if (IdpInfo info := webHost.appInfo.idProviders.get(provider)) {
                    return name == "clientId"
                        ? info.clientId
                        : utils.decrypt(webHost.secretsDecryptor, info.clientSecret);
                }
                throw new Exception($"An OAuth {provider.quoted()} provider must be configured");
            };

        default:
            if (platform) {
                // give the platform modules whatever they ask for
                @Inject ecstasy.reflect.Injector injector;
                return (Inject.Options opts) -> injector.inject(type, name, opts);
            }

            // see utils.collectDestringableInjections()
            if (AppInfo appInfo ?= appHost.appInfo,
                String  value   := appInfo.injections.get(new InjectionKey(name, type.toString()))) {
                assert type.is(Type<Destringable>) as $"Type is not Destringable: \"{type}\"";
                return new type.DataType(value);
            }
            if (Null.is(type)) {
                // allow any Nullable injections that we are not aware of
                return Null;
            }

            return (Inject.Options opts) ->
                throw new Exception($|Invalid resource: name="{name}", type="{type}"
                                   );
        }
    }
}