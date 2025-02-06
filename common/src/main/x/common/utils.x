import ecstasy.annotations.InjectedRef;

import ecstasy.mgmt.Container;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.ModuleRepository;
import ecstasy.mgmt.LinkedRepository;

import ecstasy.reflect.ClassTemplate;
import ecstasy.reflect.FileTemplate;
import ecstasy.reflect.ModuleTemplate;
import ecstasy.reflect.TypeTemplate;

import ecstasy.text.Log;

import conv.formats.Base64Format;

import crypto.Decryptor;
import crypto.KeyStore;

import model.DbAppInfo;
import model.WebAppInfo;

/**
 * The package for helper functions.
 */
package utils {
    /**
     * Create a Container for the specified template.
     *
     * @param repository  the [ModuleRepository] to load the module(s) from
     * @param template    the [ModuleTemplate] for the "main" module
     * @param appHost     the AppHost for the newly created container
     * @param errors      the logger to report errors to
     *
     * @return True iff the container has been loaded successfully
     * @return (conditional) the Container
     * @return (conditional) an array of AppHost objects for all dependent containers that have been
     *         loaded along the "main" container
     */
    static conditional (Container, AppHost[]) createContainer(
            ModuleRepository repository, ModuleTemplate template, AppHost appHost, Log errors) {

        DbHost[]     dbHosts;
        HostInjector injector;

        Map<String, String> dbNames = detectDatabases(template);
        if (dbNames.size > 0) {
            dbHosts = new DbHost[];

            assert appHost.is(WebHost);

            Directory deployDir = appHost.homeDir;
            Directory buildDir  = appHost.buildDir;

            for (String dbModuleName : dbNames.values) {
                DbHost dbHost;
                if (!(dbHost := appHost.findSharedDbHost(dbModuleName))) {
                    if (!(dbHost := createDbHost(repository, dbModuleName, Null, "jsondb",
                            deployDir, buildDir, errors))) {
                    return False;
                    }
                }
                dbHosts += dbHost;
            }
            dbHosts.makeImmutable();

            injector = new DbInjector(appHost, dbHosts);
        } else {
            dbHosts  = [];
            injector = new HostInjector(appHost);
        }

        try {
            Container container = new Container(template, Lightweight, repository, injector);
            injector.hostedContainer = container;
            return True, container, dbHosts;
        } catch (Exception e) {
            errors.add($|Error: Failed to create a container for "{template.displayName}": {e.message}
                      );
            for (DbHost dbHost : dbHosts) {
                dbHost.close(e);
            }
            return False;
        }
    }

    /**
     * @return an array of the Database module names that the specified module depends on
     */
    static Map<String, String> detectDatabases(ModuleTemplate template) {
        import ClassTemplate.Contribution;

        FileTemplate        fileTemplate = template.parent;
        Map<String, String> dbNames      = new HashMap();

        for ((String name, String dependsOn) : template.moduleNamesByPath) {
            if (dependsOn != TypeSystem.MackKernel) {
                assert ModuleTemplate depModule := fileTemplate.getModule(dependsOn);
                if (isDbModule(depModule)) {
                    dbNames.put(name, dependsOn);
                }
            }
        }
        return dbNames;
    }

    /**
     * Create a DbHost for the specified db module.
     *
     * @param repository  the [ModuleRepository] to load the module(s) from
     * @param moduleName  the name of `Database` module (fully qualified)
     * @param appInfo     (optional) [DbAppInfo] (`Null` for embedded DB)
     * @param dbImpl      the database implementation name (currently always "jsondb")
     * @param deployDir   the application deployment directory
     *                    (e.g. "~/xqiz.it/accounts/self/deploy/banking")
     * @param buildDir    the directory for auto-generated modules
     *                    (e.g. "~/xqiz.it/accounts/self/build")
     * @param errors      the logger to report errors to
     *
     * @return True if the DbHost was successfully created; False otherwise (the errors are logged)
     * @return (conditional) the DbHost
     */
    static conditional DbHost createDbHost(
            ModuleRepository repository, String moduleName, DbAppInfo? appInfo, String dbImpl,
            Directory deployDir, Directory buildDir, Log errors) {

        Directory homeDir = deployDir.dirFor(moduleName).ensure();

        switch (dbImpl) {
        case "":
        case "jsondb":
            return True, new JsondbHost(repository, moduleName, appInfo, homeDir, buildDir);

        default:
            errors.add($"Error: Unknown db implementation: {dbImpl}");
            return False;
        }
    }

    /**
     * @return True iff the specified ModuleTemplate represents a WebApp module
     */
    static Boolean isWebModule(ModuleTemplate template) {
        TypeTemplate webAppTemplate = web.WebApp.as(Type).template;
        return template.type.isA(webAppTemplate);
    }

    /**
     * @return True iff the specified ModuleTemplate represents a Database module
     */
    static Boolean isDbModule(ModuleTemplate template) {
        TypeTemplate databaseTemplate = oodb.Database.as(Type).template;
        return template.type.isA(databaseTemplate);
    }

    /**
     * Ensure the "home" directory for the specified account.
     */
    static Directory ensureAccountHomeDirectory(Directory accountsDir, String accountName) {
        // TODO: validate/convert the name
        return accountsDir.dirFor(accountName).ensure();
    }

    /**
     * Compute the size of all files in the specified directory (recursively).
     */
    static Int storageSize(Directory dir) {
        Int size = 0;
        for (File file : dir.filesRecursively()) {
            size += file.size;
        }
        return size;
    }

    /**
     * Assemble a module repository for the specified account lib directory.
     */
     static ModuleRepository getModuleRepository(Directory libDir) {
        @Inject("repository") ModuleRepository coreRepo;
        return new LinkedRepository([coreRepo, new DirRepository(libDir)].freeze(True));
    }

    /**
     * Collect all [destringable](Destringable) [model.InjectionKey]s from the specified module.
     */
    static conditional model.InjectionKey[] collectDestringableInjections(
            ModuleRepository repository, String moduleName) {

        ModuleTemplate mainModule;
        try {
            mainModule = repository.getResolvedModule(moduleName);
        } catch (Exception e) {
            return False;
        }

        import model.InjectionKey as Key;

        @Inject Container.Linker linker;
        Container.InjectionKey[] injections = linker.collectInjections(mainModule);

        return True, injections.filter(ikey -> ikey.type.isA(Destringable))
                               .map(ikey -> new Key(ikey.name, ikey.type.toString())).toArray();
    }

    /**
     * Create a decryptor using the well-known encryption key name in the specified keystore.
     */
     static Decryptor createDecryptor(KeyStore keystore) {
        assert crypto.CryptoKey key := keystore.getKey(names.PasswordEncryptionKey) as
                $"Key {names.PasswordEncryptionKey} is missing in the keystore";

        @Inject crypto.Algorithms algorithms;
        return algorithms.decryptorFor("AES", key) ?: assert;
     }

    /**
     * Encrypt a string value into a Base64 encrypted value.
     */
    static String encrypt(Decryptor decryptor, String value) =
        Base64Format.Instance.encode(decryptor.encrypt(value.utf8()));

    /**
     * Decrypt a Base64 encrypted string value.
     */
    static String decrypt(Decryptor decryptor, String value) =
        decryptor.decrypt(Base64Format.Instance.decode(value)).unpackUtf8();

    /**
     * A "new line" character as a Byte[].
     */
    static Byte[] NewLine = ['\n'.toByte()];
}