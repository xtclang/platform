/**
 * The host database.
 */
@oodb.Database
module hostDB
    {
    package oodb import oodb.xtclang.org;

    package common import common.xqiz.it;

    import common.model.AccountId;
    import common.model.AccountInfo;
    import common.model.UserId;
    import common.model.UserInfo;

    import oodb.DBMap;

    interface HostSchema
            extends oodb.RootSchema
        {
        @RO DBMap<AccountId, AccountInfo> accounts;

        @RO DBMap<UserId, UserInfo> users;
        }

    typedef (oodb.Connection<HostSchema>  + HostSchema) as Connection;

    typedef (oodb.Transaction<HostSchema> + HostSchema) as Transaction;
    }