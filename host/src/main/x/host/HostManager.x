import ecstasy.annotations.InjectedRef;

import ecstasy.io.IOException;

import ecstasy.mgmt.Container;
import ecstasy.mgmt.DirRepository;
import ecstasy.mgmt.LinkedRepository;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ClassTemplate;
import ecstasy.reflect.FileTemplate;
import ecstasy.reflect.ModuleTemplate;
import ecstasy.reflect.TypeTemplate;

import ecstasy.text.Log;

import common.AppHost;
import common.WebHost;

import common.model.AccountId;
import common.model.AccountInfo;
import common.model.UserId;
import common.model.UserInfo;

import Injector.ConsoleBuffer as Buffer;


/**
 * The module for basic hosting functionality.
 */
service HostManager
        implements common.HostManager
    {
    // ----- properties ------------------------------------------------------------------------------------------------

    /**
     * Loaded WebHost objects keyed by the application domain name.
     */
    Map<String, WebHost> loaded = new HashMap();

    @Unassigned
    DbHost platformDbHost;

    @Unassigned
    hostDB.Connection dbConnection;


    // ----- DB initialization -----------------------------------------------------------------------------------------

    /**
     * Initialize the DB connection.
     */
    void initDB(ModuleRepository repository, Log errors)
        {
        import oodb.DBMap;
        import oodb.DBUser;

        @Inject Directory homeDir;

        Directory dbDir = homeDir.dirFor($"xqiz.it/platformDB");
        dbDir.ensure();

        Directory libDir = dbDir.dirFor("build");
        libDir.ensure();

        repository = new LinkedRepository([new DirRepository(libDir), repository].freeze(True));
        assert platformDbHost := createDbHost(repository, dbDir, "hostDB", errors);

        DBUser user = new oodb.model.User(1, "admin");
        dbConnection = platformDbHost.ensureDatabase()(user).as(hostDB.Connection);

        DBMap<AccountId, AccountInfo> accounts = dbConnection.accounts;
        DBMap<UserId, UserInfo>       users    = dbConnection.users;
        if (accounts.empty)
            {
            UserInfo admin = new UserInfo(1, "admin", "admin@acme.com");
            users.put(1, admin);
            accounts.put(1, new AccountInfo(1, "acme", [], Map:[1 = Admin]));
            }
        }


    // ----- common.HostManager API ------------------------------------------------------------------------------------

    @Override
    conditional WebHost getWebHost(String domain)
        {
        return loaded.get(domain);
        }

    @Override
    conditional WebHost createWebHost(Directory userDir, String appName, String domain, Log errors)
        {
        Directory libDir;
        if (!(libDir := userDir.findDir("lib")))
            {
            errors.add($"Error: \"{userDir}/lib\" directory not found");
            return False;
            }

        Directory buildDir = userDir.dirFor("build").ensure();

        @Inject("repository") ModuleRepository coreRepo;

        ModuleRepository[] baseRepos  = [coreRepo, new DirRepository(libDir), new DirRepository(buildDir)];
        ModuleRepository   repository = new LinkedRepository(baseRepos.freeze(True));
        FileTemplate       fileTemplate;
        try
            {
            ModuleTemplate template = repository.getResolvedModule(appName);

            fileTemplate = template.parent;
            }
        catch (Exception e)
            {
            errors.add($"Error: Failed to resolve the module: {appName.quoted()} ({e.text})");
            return False;
            }

        ModuleTemplate mainModule = fileTemplate.mainModule;
        String         moduleName = mainModule.displayName;
        if (!mainModule.findAnnotation("web.WebModule"))
            {
            errors.add($"Module \"{moduleName}\" is not a WebModule");
            return False;
            }

        Directory appHomeDir = ensureHome(userDir, mainModule.qualifiedName);

        if ((Container container, AppHost[] dependents) :=
                createContainer(repository, fileTemplate, appHomeDir, False, errors))
            {
            WebHost webHost = new WebHost(container, moduleName, appHomeDir, domain,
                                createHttpServer(domain), dependents);
            loaded.put(domain, webHost);
            return True, webHost;
            }

        return False;
        }

    @Override
    void removeWebHost(WebHost webHost)
        {
        loaded.remove(webHost.domain);
        }

    @Override
    conditional AccountInfo getAccount(String accountName)
        {
        return dbConnection.accounts.values.any(info -> info.name == accountName);
        }

    @Override
    void storeAccount(AccountInfo info)
        {
        return dbConnection.accounts.put(info.id, info);
        }

    @Override
    void shutdown()
        {
        for (WebHost webHost : loaded.values)
            {
            webHost.close();
            }
        platformDbHost.closeDatabase();
        }


    // ----- helper methods ------------------------------------------------------------------------

    /**
     * Create a Container for the specified template.
     *
     * @param buildDir  the directory to place build artifacts to
     *
     * @return True iff the container has been loaded successfully
     * @return (optional) the Container
     * @return (optional) an array of AppHost objects for all dependent containers that have been
     *         loaded along the "main" container
     */
    conditional (Container, AppHost[]) createContainer(
            ModuleRepository repository, FileTemplate fileTemplate, Directory appHomeDir,
            Boolean platform, Log errors)
        {
        DbHost[] dbHosts;
        Injector injector;

        Map<String, String> dbNames = detectDatabases(fileTemplate);
        if (dbNames.size > 0)
            {
            dbHosts = new DbHost[];

            for ((String dbPath, String dbModuleName) : dbNames)
                {
                Directory userDir = appHomeDir.parent?.parent? : assert;
                DbHost    dbHost;

                if (!(dbHost := createDbHost(repository, userDir, dbModuleName, errors)))
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

        ModuleTemplate template = fileTemplate.mainModule;
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
     * @return an array of the Database module names that the specified template depends on
     */
    Map<String, String> detectDatabases(FileTemplate fileTemplate)
        {
        import ClassTemplate.Contribution;

        TypeTemplate        dbTypeTemplate = oodb.Database.as(Type).template;
        Map<String, String> dbNames        = new HashMap();

        for ((String name, String dependsOn) : fileTemplate.mainModule.moduleNamesByPath)
            {
            if (dependsOn != TypeSystem.MackKernel)
                {
                ModuleTemplate depModule = fileTemplate.getModule(dependsOn);
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
     * @return (optional) the DbHost
     */
    conditional DbHost createDbHost(
            ModuleRepository repository, Directory userDir, String dbModuleName, Log errors)
        {
        Directory      dbHomeDir = ensureHome(userDir, dbModuleName);
        DbHost         dbHost;
        ModuleTemplate dbModuleTemplate;

        @Inject Map<String, String> properties;

        switch (String impl = properties.getOrDefault("db.impl", "json"))
            {
            case "":
            case "json":
                dbHost = new JsondbHost(dbModuleName, dbHomeDir, new jsondb.tools.ModuleGenerator(dbModuleName));
                break;

            default:
                errors.add($"Error: Unknown db implementation: {impl}");
                return False;
            }

        Directory buildDir = userDir.dirFor("build").ensure();

        if (!(dbModuleTemplate := dbHost.generator.ensureDBModule(repository, buildDir, errors)))
            {
            errors.add($"Error: Failed to create a host for : {dbModuleName}");
            return False;
            }

        dbHost.container = new Container(dbModuleTemplate, Lightweight, repository,
                                new Injector(dbHomeDir, False));
        dbHost.makeImmutable();
        return True, dbHost;
        }

    /**
     * @return an Injector that injects db connections based on the arrays of the specified DbHosts
     */
    Injector createDbInjector(DbHost[] dbHosts, Directory appHomeDir)
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
     */
    Directory ensureHome(Directory userDir, String moduleName)
        {
        return userDir.dirFor($"host/{moduleName}").ensure();
        }

    /**
     * TODO: temporary
     */
    HttpServer createHttpServer(String domain)
        {
        String address = $"{domain}.xqiz.it:8080";
        // TODO: ensure a DNS entry
        @Inject(opts=address) HttpServer server;
        return server;
        }
    }