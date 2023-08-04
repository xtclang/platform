/**
 * The platform database.
 */
@oodb.Database
module platformDB2.xqiz.it {
    package oodb import oodb.xtclang.org;

    package common import common.xqiz.it;

    import common.model2.AccountId;
    import common.model2.AccountInfo;
    import common.model2.UserId;
    import common.model2.UserInfo;

    import oodb.DBMap;

    interface Schema
            extends oodb.RootSchema {

        @RO DBMap<AccountId, AccountInfo> accounts;

        @RO DBMap<UserId, UserInfo> users;

        /**
         * Temporary, until the automatic DNS registration is implemented.
         * Holds the HTTP ports allocated to accounts.
         */
        @RO DBMap<UInt16, AccountId> allocatedPorts;
    }

    typedef (oodb.Connection<Schema>  + Schema) as Connection;

    typedef (oodb.Transaction<Schema> + Schema) as Transaction;
}