import common.AppHost;

import oodb.RootSchema;

import oodb.tools.ModuleGenerator;

/**
 * An abstract host for a DB module.
 */
@Abstract
class DbHost(String dbModuleName, Directory homeDir, ModuleGenerator generator)
        extends AppHost(dbModuleName, homeDir)
    {
    /**
     * The ModuleGenerator to be used with this DbHost.
     */
    public/private ModuleGenerator generator;

    /**
     * The actual [RootSchema] type associated with the DB module represented by this DbHost.
     */
    @RO Type<RootSchema> schemaType;

    /**
     * Check an existence of the DB (e.g. on disk); create or recover if necessary.
     *
     * @return a connection factory
     */
    function oodb.Connection(oodb.DBUser)
        ensureDatabase(Map<String, String>? configOverrides = Null);

    /**
     * Life cycle: close the database.
     */
    void closeDatabase();


    // ----- Closeable -------------------------------------------------------------------------------------------------

    @Override
    void close(Exception? e)
        {
        closeDatabase();
        }
    }