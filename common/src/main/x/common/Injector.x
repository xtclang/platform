import ecstasy.lang.src.Compiler;

import ecstasy.annotations.InjectedRef;

import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.ResourceProvider;

import crypto.Algorithms;
import crypto.KeyStore;

import web.security.Authenticator;

import xenia.HttpServer;

/**
 * The Injector service.
 */
service Injector(Directory appHomeDir, Boolean platform)
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
        void print(Object o, Boolean suppressNewline=False) {
            write(o.is(String) ? o : o.toString(), suppressNewline);
        }

        @Override
        String readLine(Boolean suppressEcho = False) {
            throw new UnsupportedOperation();
        }

        void write(String s, Boolean suppressNewline) {
            consoleFile.append(s.utf8());
            if (!suppressNewline) {
                consoleFile.append(['\n'.toByte()]);
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

                Directory temp = store.root.find("_temp").as(Directory);
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

        default:
            // HttpServer is not a shared Ecstasy type, so it's not handled by the switch()
            if (type.is(Type<HttpServer>) && name == "server") {
                return (InjectedRef.Options address) -> {
                    @Inject(resourceName="server", opts=address) HttpServer server;
                    return server;
                };
            }

            return (InjectedRef.Options address) ->
                throw new Exception($|Invalid resource: type="{type}", name="{name}"
                                   );
        }
    }
}