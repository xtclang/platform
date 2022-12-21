import ecstasy.annotations.InjectedRef;

import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ClassTemplate;
import ecstasy.reflect.FileTemplate;
import ecstasy.reflect.ModuleTemplate;
import ecstasy.reflect.TypeTemplate;

import ecstasy.text.Log;


package utils
    {
    // ----- helper methods ------------------------------------------------------------------------

    /**
     * Create a Container for the specified template.
     *
     * @param repository  the [ModuleRepository] to load the module(s) from
     * @param template    the [ModuleTemplate] for the "main" module
     * @param appHomeDir  the "home" directory for the module (e.g. "~/xqiz.it/users/acme/host/shopping)"
     * @param platform    True iff the loading module is one of the "core" platform modules
     *
     * @return True iff the container has been loaded successfully
     * @return (optional) the Container
     * @return (optional) an array of AppHost objects for all dependent containers that have been
     *         loaded along the "main" container
     */
    static conditional (Container, AppHost[]) createContainer(
                    ModuleRepository repository, ModuleTemplate template, Directory appHomeDir,
                    Boolean platform, Log errors)
        {
        DbHost[] dbHosts;
        Injector injector;

        Map<String, String> dbNames = detectDatabases(template);
        if (dbNames.size > 0)
            {
            dbHosts = new DbHost[];

            for ((String dbPath, String dbModuleName) : dbNames)
                {
                Directory userDir = appHomeDir.parent?.parent? : assert;
                DbHost    dbHost;

                if (!(dbHost := createDbHost(repository, userDir, dbModuleName, "jsondb", errors)))
                    {
                    return False;
                    }
                dbHosts += dbHost;
                }
            dbHosts.makeImmutable();

            injector = createDbInjector(dbHosts, appHomeDir);
            }
        else
            {
            dbHosts  = [];
            injector = new Injector(appHomeDir, platform);
            }

        try
            {
            return True, new Container(template, Lightweight, repository, injector), dbHosts;
            }
        catch (Exception e)
            {
            errors.add($"Failed to load \"{template.displayName}\": {e.text}");
            return False;
            }
        }

    /**
     * @return an array of the Database module names that the specified module depends on
     */
    static Map<String, String> detectDatabases(ModuleTemplate template)
        {
        import ClassTemplate.Contribution;

        FileTemplate        fileTemplate   = template.parent;
        TypeTemplate        dbTypeTemplate = oodb.Database.as(Type).template;
        Map<String, String> dbNames        = new HashMap();

        for ((String name, String dependsOn) : template.moduleNamesByPath)
            {
            if (dependsOn != TypeSystem.MackKernel)
                {
                assert ModuleTemplate depModule := fileTemplate.getModule(dependsOn);
                if (depModule.type.isA(dbTypeTemplate))
                    {
                    dbNames.put(name, dependsOn);
                    }
                }
            }
        return dbNames;
        }

    /**
     * Create a DbHost for the specified db module.
     *
     * @param repository    the [ModuleRepository] to load the module(s) from
     * @param userDir       the user `Directory` (e.g. "~/xqiz.it/users/acme/")
     * @param dbModuleName  the name of `Database` module (fully qualified)
     * @param dbImpl        the database implementation name (currently always "jsondb")
     *
     * @return (optional) the DbHost
     */
    static conditional DbHost createDbHost(
            ModuleRepository repository, Directory userDir, String dbModuleName, String dbImpl, Log errors)
        {
        import jsondb.tools.ModuleGenerator;

        Directory       dbHomeDir = ensureHome(userDir, dbModuleName);
        DbHost          dbHost;
        ModuleTemplate  dbModuleTemplate;
        ModuleGenerator generator;

        switch (dbImpl)
            {
            case "":
            case "jsondb":
                dbHost    = new JsondbHost(dbModuleName, dbHomeDir);
                generator = new jsondb.tools.ModuleGenerator(dbModuleName);
                break;

            default:
                errors.add($"Error: Unknown db implementation: {dbImpl}");
                return False;
            }

        Directory buildDir = userDir.dirFor("build").ensure();

        if (!(dbModuleTemplate := generator.ensureDBModule(repository, buildDir, errors)))
            {
            errors.add($"Error: Failed to create a DB host for : {dbModuleName}");
            return False;
            }

        dbHost.container = new Container(dbModuleTemplate, Lightweight, repository,
                                new Injector(dbHomeDir, False));
        dbHost.makeImmutable();
        return True, dbHost;
        }

    /**
     * Create a database [Injector].
     *
     * @param dbHosts     the array of [DbHost]s for databases the Injector should be able to provide connections to
     * @param appHomeDir  the "home" directory for the module (e.g. "~/xqiz.it/users/acme/host/shopping)"
     *
     * @return an Injector that injects db connections based on the arrays of the specified DbHosts
     */
    static Injector createDbInjector(DbHost[] dbHosts, Directory appHomeDir)
        {
        import oodb.Connection;
        import oodb.RootSchema;
        import oodb.DBUser;

        return new Injector(appHomeDir, False)
            {
            @Override
            Supplier getResource(Type type, String name)
                {
                if (type.is(Type<RootSchema>) || type.is(Type<Connection>))
                    {
                    Type schemaType;
                    if (type.is(Type<RootSchema>))
                        {
                        schemaType = type;
                        }
                    else
                        {
                        assert schemaType := type.resolveFormalType("Schema");
                        }

                    for (DbHost dbHost : dbHosts)
                        {
                        // the actual type that "createConnection" produces is:
                        // RootSchema + Connection<RootSchema>;

                        Type dbSchemaType   = dbHost.schemaType;
                        Type typeConnection = Connection;

                        typeConnection = dbSchemaType + typeConnection.parameterize([dbSchemaType]);
                        if (typeConnection.isA(schemaType))
                            {
                            function Connection(DBUser) createConnection = dbHost.ensureDatabase();

                            return (InjectedRef.Options opts) ->
                                {
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
     * Ensure a home directory for the specified module.
     *
     * @param userDir     the user 'Directory' (e.g. "~/xqiz.it/users/acme/")
     * @param moduleName  the application module name
     *
     * @return the "home" directory for the module (e.g. "~/xqiz.it/users/acme/host/welcome)"
     */
    static Directory ensureHome(Directory userDir, String moduleName)
        {
        return userDir.dirFor($"host/{moduleName}").ensure();
        }
    }