import ecstasy.lang.src.Compiler;

import ecstasy.annotations.InjectedRef;

import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.ResourceProvider;

import crypto.Algorithms;
import crypto.KeyStore;

import web.security.Authenticator;

import web.ssssion.Broker;

import model.InjectionKey;
import model.Injections;

/**
 * The ResourceProvider used for hosted containers.
 */
service HostInjector(Directory appHomeDir, Boolean platform, Injections injections)
        implements ResourceProvider {

    @Lazy FileStore store.calc() {
        import ecstasy.fs.DirectoryFileStore;

        return new DirectoryFileStore(appHomeDir);
    }

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

        case (Authenticator?, "providedAuthenticator"):
            return (InjectedRef.Options address) -> {
                // TODO GG/CP: this is a big todo...
                return Null;
            };

        case (Broker?, "sessionBroker"):
            return (InjectedRef.Options address) -> {
                // TODO GG/CP: this is another todo...
                return Null;
            };

        default:
            if (platform) {
                @Inject ecstasy.reflect.Injector injector;
                return (InjectedRef.Options opts) -> injector.inject(type, name, opts);
            }

            // see utils.collectDestringableInjections()
            if (String value := injections.get(new InjectionKey(name, type.toString()))) {
                assert type.is(Type<Destringable>) as $|Type is not Destringable: "{type}"
                                                       ;
                return new type.DataType(value);
            }
            if (Null.is(type)) {
                // allow any Nullable injection that we are not aware of
                return Null;
            }

            return (InjectedRef.Options address) ->
                throw new Exception($|Invalid resource: name="{name}", type="{type}"
                                   );
        }
    }
}