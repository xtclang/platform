import ecstasy.annotations.InjectedRef;

import ecstasy.text.Log;

import oodb.Connection;
import oodb.RootSchema;
import oodb.DBUser;

import oodb.model.User;

import web.WebApp;
import web.WebService;

import web.security.Authenticator;
import web.security.ChainAuthenticator;
import web.security.DigestAuthenticator;
import web.security.DigestCredential;
import web.security.TokenAuthenticator;

import webauth.Configuration;
import webauth.DBRealm;

import model.AppInfo;
import model.Injections;
import model.WebAppInfo;

import platformAuth.UserEndpoint;

/**
 * HostInjector that is aware of the databases to be injected.
 */
service DbInjector
        extends HostInjector {

    /**
     * Construct a DbInjector.
     *
     * @param appInfo     [AppInfo] for the hosted module
     * @param dbHosts     the array of [DbHost]s for databases the Injector should be able to provide
     *                    connections to
     * @param deployDir   the "home" directory for the deployment
     *                    (e.g. "~/xqiz.it/accounts/self/deploy/shopping")
     * @param injections  the custom injections
     */
    construct(AppInfo appInfo, DbHost[] dbHosts, Directory deployDir, Injections injections) {
        assert !dbHosts.empty;
        this.dbHosts = dbHosts;

        construct HostInjector(appInfo, deployDir, False, injections);
    }

    typedef function Connection(DBUser) as ConnectionFactory;

    /**
     * The array of [DbHost]s for databases to provide connection to.
     */
    private DbHost[] dbHosts;

    /**
     * The array of created connections. Used only for automatic closing.
     */
    private Connection[] connections = new Connection[];

    /**
     * The DBUser to use for creating connections.
     */
    @Lazy DBUser user.calc() = new User(1, appInfo.deployment);

    @Override
    AppInfo appInfo.get() = super().as(AppInfo);

    @Override
    Supplier getResource(Type type, String name) {
        // first, check for any subclass of the "RootSchema"
        if (type.is(Type<RootSchema>)) {
            Type schemaType = type;
            if (type.is(Type<Connection>)) {
                assert schemaType := type.resolveFormalType("Schema");
            }

            // Note, that we activate the dbHosts during the container validation phase to minimize
            // DB-related initialization costs for a started application
            Log errors = new ErrorLog();
            for (DbHost dbHost : dbHosts) {
                if (ConnectionFactory createConnection := dbHost.activate(False, errors)) {
                    // the actual type that "createConnection" produces is:
                    //   "AppDbSchema + Connection<AppDbSchema>", where AppDbSchema extends RootSchema
                    Type hostSchemaType = dbHost.schemaType;
                    Type hostConnType   = hostSchemaType + Connection.as(Type).parameterize([hostSchemaType]);
                    if (hostConnType.isA(schemaType)) {
                        return (InjectedRef.Options opts) -> maskConnection(createConnection, type);
                    }
                } else {
                    errors.reportAll(consoleImpl.print);
                    throw new Exception($"Failed to activate the database {type}/{name}");
                }
            }
            throw new Exception($"Failed to find a database for {schemaType}");
        }

        switch (type, name) {
        case (Authenticator?, "authenticator"):
            return (InjectedRef.Options opts) -> {
                if (WebAppInfo appInfo := this.appInfo.is(WebAppInfo), appInfo.useAuth) {

                    Configuration initConfig = new Configuration(
                        initUserPass = ["admin"="password"],
                        credScheme   = DigestCredential.Scheme,
                        );

                    RootSchema db;
                    Log        errors = new ErrorLog();
                    if (dbHosts.size == 1) {
                        if (ConnectionFactory createConnection := dbHosts[0].activate(False, errors)) {
                            db = maskConnection(createConnection, RootSchema);
                        } else {
                            errors.reportAll(consoleImpl.print);
                            return Null;
                        }
                    } else {
                        RootSchema? schema = Null;
                        Boolean     found  = False;
                        for (DbHost dbHost : dbHosts) {
                            if (ConnectionFactory createConnection := dbHost.activate(False, errors)) {
                                schema = maskConnection(createConnection, RootSchema);
                                if (DBRealm.findAuthSchema(schema)) {
                                    if (found) {
                                        consoleImpl.print($|Multiple "AuthSchema" instances found \
                                                           |in {appInfo.deployment} database
                                                         );
                                        return Null;
                                    } else {
                                        found = True;
                                    }
                                }
                            } else {
                                errors.reportAll(consoleImpl.print);
                                return Null;
                            }
                        }
                        if (schema == Null) {
                            consoleImpl.print($|The database for {appInfo.deployment} does not \
                                               |contain an "AuthSchema\"
                                             );
                            return Null;
                        } else {
                            db = schema;
                        }
                    }

                    // main module is a wrapper (see _webModule.txt resource)
                    WebApp  webApp = hostedContainer.invoke("hostedWebApp_")[0].as(WebApp);
                    DBRealm realm  = new DBRealm(appInfo.deployment,
                                                 rootSchema=db, initConfig=initConfig);
                    // allow both digest (principal) and token based (entitlements) authentication
                    Authenticator authenticator = new UserEndpoint(webApp, realm,
                        new ChainAuthenticator(realm, [
                            new DigestAuthenticator(realm),
                            new TokenAuthenticator(realm),
                        ]));
                    return &authenticator.maskAs(Authenticator+WebService.ExtrasAware);
                }
                return Null;
            };
        }
        return super(type, name);

        private RootSchema maskConnection(ConnectionFactory createConnection, Type<RootSchema> type) {
            Connection conn = createConnection(user);
            connections += conn;
            return type.is(Type<Connection>)
                    ? &conn.maskAs<Connection>(type)
                    : &conn.maskAs<RootSchema>(type);
        }
    }

    @Override
    void close(Exception? cause = Null) {
        connections.forEach(c -> c.close(cause));
    }
}
