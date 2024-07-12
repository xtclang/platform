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
class JsondbHost(String dbModuleName, Directory homeDir)
        extends DbHost(dbModuleName, homeDir) {
    /**
     * Cached CatalogMetadata instance.
     */
    @Lazy CatalogMetadata meta.calc() {
        return container?.innerTypeSystem.primaryModule.as(CatalogMetadata) : assert;
    }

    /**
     * Cached Catalog instance.
     */
    @Lazy Catalog catalog.calc() {
        Directory dataDir = homeDir.dirFor("data").ensure();
        Catalog   catalog = meta.createCatalog(dataDir, False);
        catalog.ensureOpenDB(dbModuleName);
        return catalog;
    }

    @Override
    Type<RootSchema> schemaType.get() {
        return meta.Schema;
    }

    @Override
    function oodb.Connection(DBUser) ensureDatabase() {
        return meta.ensureConnectionFactory(catalog);
    }

    @Override
    void closeDatabase() {
        catalog.close();
    }
}