import ecstasy.mgmt.Container;
import ecstasy.mgmt.ModuleRepository;

import ecstasy.reflect.ModuleTemplate;

import ecstasy.text.Log;

import jsondb.Catalog;
import jsondb.CatalogMetadata;

import jsondb.tools.ModuleGenerator;

import oodb.Connection;
import oodb.DBUser;
import oodb.RootSchema;

import common.model.DbAppInfo;
import common.model.Injections;

/**
 * Host for jsondb-based DB module.
 */
service JsondbHost(ModuleRepository repository, String moduleName, DbAppInfo? appInfo,
                  Directory homeDir, Directory buildDir)
        extends DbHost(repository, moduleName, appInfo, homeDir, buildDir) {

    /**
     * Cached CatalogMetadata instance.
     */
    protected CatalogMetadata? meta;

    /**
     * Cached Catalog instance.
     */
    protected Catalog? catalog;

    @Override
    Boolean active.get() = catalog != Null;

    @Override
    Type<RootSchema> schemaType.get() {
        return meta?.Schema : assert;
    }

    @Override
    conditional function oodb.Connection(DBUser) activate(Boolean explicit, Log errors) {
        if (!super(explicit, errors)) {
            return False;
        }

        if (meta == Null) {
            Injections      injections = appInfo?.injections : [];
            ModuleGenerator generator  = new ModuleGenerator(moduleName);
            ModuleTemplate  template;

            if (!(template := generator.ensureDBModule(repository, buildDir, errors))) {
                errors.add($"Error: Failed to create a DB host for {moduleName.quoted()}");
                return False;
            }

            HostInjector injector  = new HostInjector(this);
            Container    container = new Container(template, Lightweight, repository, injector);

            injector.hostedContainer = container;

            CatalogMetadata meta = container.innerTypeSystem.primaryModule.as(CatalogMetadata);

            Directory dataDir = homeDir.dirFor("data").ensure();
            Catalog   catalog = meta.createCatalog(dataDir, False);
            catalog.ensureOpenDB(moduleName);

            this.meta      = meta;
            this.catalog   = catalog;
            this.container = container;
        }
        return True, meta?.ensureConnectionFactory(catalog?) : assert;
    }

    @Override
    Boolean deactivate(Boolean explicit) {
        Boolean doClose = super(explicit);
        if (doClose) {
            close();
            container = Null;
            catalog   = Null;
            meta      = Null;
        }
        return doClose;
    }

    @Override
    void close(Exception? e = Null) {
        try {
            catalog?.close();
        } catch (Exception e2) {
            log($"Exception during closing of {this}: {e2.message}");
        }
    }
}