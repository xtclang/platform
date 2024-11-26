/**
 * The platform database.
 */
@oodb.Database
module platformDB.xqiz.it {
    package auth   import webauth.xtclang.org;
    package oodb   import oodb.xtclang.org;
    package common import common.xqiz.it;
    package web    import web.xtclang.org;

    import common.model.AccountId;
    import common.model.AccountInfo;
    import common.model.UserId;
    import common.model.UserInfo;

    import common.names;

    import oodb.DBCounter;
    import oodb.DBMap;
    import oodb.NoTx;

    interface Schema
            extends oodb.RootSchema {

        /**
         * DBMap of accounts.
         */
        @RO Accounts accounts;

        /**
         * DBMap of users.
         */
        @RO Users users;

        /**
         * Internal account id generator.
         */
        @RO @NoTx DBCounter accountId;

        /**
         * Embedded AuthSchema.
         */
        @RO auth.AuthSchema authSchema;
    }

    mixin Accounts
            into DBMap<AccountId, AccountInfo> {
        /**
         * @see [AccountManager.createAccount]
         */
        conditional AccountInfo create(String accountName) {
            if (values.any(info -> info.name == accountName)) {
                return False;
            }

            Schema      schema  = dbRoot.as(Schema);
            AccountId   id      = schema.accountId.next();
            AccountInfo account = new AccountInfo(id, accountName);

            put(id, account);
            return True, account;
        }

        /**
         * @see [AccountManager.updateAccount]
         */
        Boolean update(AccountInfo account) {
            AccountInfo current;
            if (!(current := get(account.id))) {
                return False;
            }

            String name = account.name;
            if (current.name != name &&
                values.any(info -> info.name == name)) {
                return False;
            }

            put(current.id, account);
            return True;
        }
    }

    mixin Users
            into DBMap<UserId, UserInfo> {
        /**
         * @see [AccountManager.createUser]
         */
        conditional UserInfo create(UserId userId, String userName, String email) {
            if (values.any(info -> info.name == userName || info.email == email)) {
                return False;
            }

            Schema   schema = dbRoot.as(Schema);
            UserInfo user   = new UserInfo(userId, userName, email);

            put(userId, user);
            return True, user;
        }

        /**
         * @see [AccountManager.updateUser]
         */
        Boolean update(UserInfo user) {
            UserId   userId = user.id;
            UserInfo current;
            if (!(current := get(userId))) {
                return False;
            }

            String name  = user.name;
            String email = user.email;
            if (current.name != name &&
                values.any(info -> info.name == name)) {
                return False;
            }
            if (current.email != email &&
                values.any(info -> info.email == email)) {
                return False;
            }
            put(userId, current.with(name, email));
            return True;
        }
    }

    typedef (oodb.Connection<Schema>  + Schema) as Connection;
    typedef (oodb.Transaction<Schema> + Schema) as Transaction;
}