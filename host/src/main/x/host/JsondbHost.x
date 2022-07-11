import ecstasy.text.Log;

import jsondb.Catalog;
import jsondb.CatalogMetadata;

import jsondb.tools.ModuleGenerator;

import oodb.Connection;
import oodb.DBUser;
import oodb.RootSchema;

/**
 * Host for jsondb-based DB module.
 */
class JsondbHost(String dbModuleName, Directory homeDir, ModuleGenerator generator)
        extends DbHost(dbModuleName, homeDir, generator)
    {
    /**
     * Cached CatalogMetadata instance.
     */
    @Lazy CatalogMetadata meta.calc()
        {
        return container.innerTypeSystem.primaryModule.as(CatalogMetadata);
        }

    /**
     * Cached Catalog instance.
     */
    @Lazy Catalog catalog.calc()
        {
        Directory dataDir = homeDir.dirFor("data").ensure();
        Catalog   catalog = meta.createCatalog(dataDir, False);
        catalog.ensureOpenDB(dbModuleName);
        return catalog;
        }

    @Override
    Type<RootSchema> schemaType.get()
        {
        return meta.Schema;
        }

    @Override
    function oodb.Connection(DBUser) ensureDatabase(Map<String, String>? configOverrides = Null)
        {
        return meta.ensureConnectionFactory(catalog);
        }

    @Override
    void closeDatabase()
        {
        catalog.close();
        }
    }