import ecstasy.lang.src.Compiler;

import ecstasy.annotations.InjectedRef;

import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.ResourceProvider;

import crypto.Algorithms;
import crypto.KeyStore;

import web.WebApp;
import web.WebService;

import web.sessions.Broker;

import model.AppInfo;
import model.InjectionKey;
import model.Injections;
import model.WebAppInfo;

/**
 * The ResourceProvider used for hosted containers.
 */
service HostInjector(AppInfo? appInfo, Directory appHomeDir, Boolean platform, Injections injections)
        implements ResourceProvider {

    /**
     * The hosted container.
     *
     * Quite naturally, there is a catch-22: we need an injector to instantiate a container, so this
     * value can get provided only after the container is created.
     */
    @Unassigned Container hostedContainer;

    /**
     * The [FileStore] allocated for the hosted container.
     */
    @Lazy FileStore store.calc() = new ecstasy.fs.DirectoryFileStore(appHomeDir);

    /**
     * The [Console] for the hosted container.
     */
    @Lazy ConsoleImpl consoleImpl.calc() {
        File consoleFile = appHomeDir.fileFor("console.log");
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
        @Override
        void print(Object o = "", Boolean suppressNewline = False) {
            write(o.is(String) ? o : o.toString(), suppressNewline);
        }

        @Override
        String readLine(String prompt = "", Boolean suppressEcho = False) {
            throw new Unsupported();
        }

        void write(String s, Boolean suppressNewline) {
            consoleFile.append(s.utf8());
            if (!suppressNewline) {
                consoleFile.append(utils.NewLine);
            }
        }
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
            return (InjectedRef.Options opts) -> {
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
            return (InjectedRef.Options opts) -> {
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
            return (InjectedRef.Options opts) -> {
                @Inject(opts=opts) Algorithms algorithms;
                return algorithms;
            };

        case (KeyStore, "keystore"):
            return (InjectedRef.Options opts) -> {
                @Inject(opts=opts) KeyStore keystore;
                return keystore;
            };

        case (Broker?, "sessionBroker"):
            return (InjectedRef.Options opts) -> {
                AppInfo? appInfo = this.appInfo;
                WebApp   webApp;
                if (platform) {
                    // platformUI (WebApp) uses CookieBroker
                    if (webApp := hostedContainer.innerTypeSystem.primaryModule.is(WebApp)) {
                    } else {
                        return Null;
                    }
                } else {
                    if (appInfo.is(WebAppInfo) && appInfo.useCookies) {
                        // main module is a wrapper (see _webModule.txt resource)
                        webApp = hostedContainer.invoke("hostedWebApp_")[0].as(WebApp);
                    } else {
                        return Null;
                    }
                }

                val broker = new xenia.CookieBroker(webApp);

                // TODO: ideally, what we want is to mask an intersection, but WebService
                //       is a mixin, and is not proxy-able atm
                // return &broker.maskAs(Broker+WebService);

                // this relies on sharing "xenia" module with the hosted container
                // (see utils.createContainer)
                return broker;
            };

        default:
            if (platform) {
                // give the platform modules whatever they ask for
                @Inject ecstasy.reflect.Injector injector;
                return (InjectedRef.Options opts) -> injector.inject(type, name, opts);
            }

            // see utils.collectDestringableInjections()
            if (String value := injections.get(new InjectionKey(name, type.toString()))) {
                assert type.is(Type<Destringable>) as $"Type is not Destringable: \"{type}\"";
                return new type.DataType(value);
            }
            if (Null.is(type)) {
                // allow any Nullable injections that we are not aware of
                return Null;
            }

            return (InjectedRef.Options address) ->
                throw new Exception($|Invalid resource: name="{name}", type="{type}"
                                   );
        }
    }
}