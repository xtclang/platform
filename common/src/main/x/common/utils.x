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

import model.DbAppInfo;
import model.Injections;

/**
 * The package for helper functions.
 */
package utils {
    /**
     * Create a Container for the specified template.
     *
     * @param repository  the [ModuleRepository] to load the module(s) from
     * @param template    the [ModuleTemplate] for the "main" module
     * @param deployDir   the "home" directory for the deployment
     *                    (e.g. "~/xqiz.it/accounts/self/deploy/banking)"
     * @param buildDir    the directory for auto-generated modules
     *                    (e.g. "~/xqiz.it/accounts/self/build")
     * @param platform    True iff the loading module is one of the "core" platform modules
     * @param injections  the custom injections
     * @param findDbHost  a function that may supply a shared DbHost for a given database module
     * @param errors      the logger to report errors to
     *
     * @return True iff the container has been loaded successfully
     * @return (conditional) the Container
     * @return (conditional) an array of AppHost objects for all dependent containers that have been
     *         loaded along the "main" container
     */
    static conditional (Container, AppHost[]) createContainer(
                    ModuleRepository repository, ModuleTemplate template, Directory deployDir,
                    Directory buildDir, Boolean platform, Injections injections,
                    function conditional DbHost(String) findDbHost, Log errors) {
        DbHost[]     dbHosts;
        HostInjector injector;

        Map<String, String> dbNames = detectDatabases(template);
        if (dbNames.size > 0) {
            dbHosts = new DbHost[];

            for (String dbModuleName : dbNames.values) {
                DbHost dbHost;
                if (!(dbHost := findDbHost(dbModuleName))) {
                    if (!(dbHost := createDbHost(repository, dbModuleName, Null, "jsondb",
                            deployDir, buildDir, errors))) {
                    return False;
                    }
                }
                dbHosts += dbHost;
            }
            dbHosts.makeImmutable();

            injector = createDbInjector(dbHosts, deployDir, injections);
        } else {
            dbHosts  = [];
            injector = new HostInjector(deployDir, platform, injections);
        }

        try {
            return True, new Container(template, Lightweight, repository, injector), dbHosts;
        } catch (Exception e) {
            errors.add($|Error: Failed to load "{template.displayName}": {e.message}
                      );
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
     * @param appInfo     (optional) DbAppInfo (Null for embedded DB)
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
     * Create a database [HostInjector].
     *
     * @param dbHosts     the array of [DbHost]s for databases the Injector should be able to provide
     *                    connections to
     * @param deployDir   the "home" directory for the deployment
     *                    (e.g. "~/xqiz.it/accounts/self/deploy/shopping")
     * @param injections  the custom injections
     *
     * @return a HostInjector that injects db connections based on the arrays of the specified DbHosts
     */
    static HostInjector createDbInjector(DbHost[] dbHosts, Directory deployDir, Injections injections) {
        import oodb.Connection;
        import oodb.RootSchema;
        import oodb.DBUser;

        return new HostInjector(deployDir, False, injections) {
            @Override
            Supplier getResource(Type type, String name) {
                if (type.is(Type<RootSchema>)) {
                    Type schemaType = type;
                    if (type.is(Type<Connection>)) {
                        assert schemaType := type.resolveFormalType("Schema");
                    }

                    Log errors = new ErrorLog();

                    for (DbHost dbHost : dbHosts) {
                        // the actual type that "createConnection" produces is:
                        // RootSchema + Connection<RootSchema>;

                        function Connection(DBUser) createConnection;
                        if (!(createConnection := dbHost.activate(False, errors))) {
                            errors.reportAll(consoleImpl.print);
                            throw new Exception($"Failed to activate the database {type}/{name}");
                        }

                        Type dbSchemaType   = dbHost.schemaType;
                        Type typeConnection = Connection;

                        typeConnection = dbSchemaType + typeConnection.parameterize([dbSchemaType]);
                        if (typeConnection.isA(schemaType)) {
                            return (InjectedRef.Options opts) -> {
                                // consider the injector to be passed some info about the calling
                                // container, so the host could figure out the user
                                DBUser     user = new oodb.model.User(1, "test");
                                Connection conn = createConnection(user);
                                return type.is(Type<Connection>)
                                        ? &conn.maskAs<Connection>(type)
                                        : &conn.maskAs<RootSchema>(type);
                            };
                        }
                    }
                }
                return super(type, name);
            }
        };
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

    static Byte[] NewLine = ['\n'.toByte()];
}