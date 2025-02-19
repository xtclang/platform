import ecstasy.mgmt.ModuleRepository;

import ecstasy.text.Log;

import common.AppHost;

import common.model.DbAppInfo;

import oodb.Connection;
import oodb.DBUser;
import oodb.RootSchema;

/**
 * An abstract host for a DB module.
 */
@Abstract
service DbHost(ModuleRepository repository, String moduleName, DbAppInfo? appInfo,
             Directory homeDir, Directory buildDir)
        extends AppHost(moduleName, appInfo, homeDir, buildDir) {

    /**
     * The module repository to use.
     */
    protected ModuleRepository repository;

    /**
     * True iff the DbHost is a standalone host shared by multiple web applications.
     */
    protected Boolean shared.get() = appInfo != Null;

    /**
     * The number of hosts that depend on this DbHost. This counter is only used for shared DB apps.
     */
    Int dependees;

    @Override
    DbAppInfo? appInfo.get() = super().as(DbAppInfo?);

    /**
     * The actual [RootSchema] type associated with the DB module represented by this DbHost.
     */
    @RO Type<RootSchema> schemaType;

    /**
     * Check an existence of the DB; create or recover if necessary.
     *
     * @param explicit  True if the activation request comes from the platform management UI;
     *                  False if it's caused by a dynamic application DB injection
     *
     * @return True iff the hosted DbApp is active
     * @return (conditional) a connection factory
     */
    @Override
    conditional function Connection(DBUser) activate(Boolean explicit, Log errors) {
        if (shared && !explicit) {
            dependees++;
        }
        return True, _ -> throw new NotImplemented();
    }

    @Override
    Boolean deactivate(Boolean explicit) {
        if (shared) {
            --dependees;
        }
        return explicit || dependees == 0;
    }
}