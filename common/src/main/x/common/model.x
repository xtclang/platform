package model {
    typedef Int as AccountId;
    typedef Int as UserId;

    enum UserRole {Admin, Developer, Observer}

    const AccountInfo(AccountId id, String name,
                      Map<String, ModuleInfo> modules = [], // keyed by the fully qualified name
                      Map<String, AppInfo>    apps    = [], // keyed by the deployment name
                      Map<UserId, UserRole>   users   = []
                      ) {

        AccountInfo addOrUpdateModule(ModuleInfo info) {
            return new AccountInfo(id, name, modules.put(info.name, info), apps, users);
        }

        AccountInfo removeModule(String moduleName) {
            return new AccountInfo(id, name, modules.remove(moduleName), apps, users);
        }

        AccountInfo addOrUpdateUser(UserId userId, UserRole role) {
            return new AccountInfo(id, name, modules, apps, users.put(userId, role));
        }

        AccountInfo removeUser(UserId userId) {
            return new AccountInfo(id, name, modules, apps, users.remove(userId));
        }

        AccountInfo addOrUpdateApp(AppInfo info) {
            return new AccountInfo(id, name, modules, apps.put(info.deployment, info), users);
        }

        AccountInfo removeApp(String deployment) {
            return new AccountInfo(id, name, modules, apps.remove(deployment), users);
        }

        /**
         * @return the name of deployments that depend on the specified module(s)
         */
        Set<String> collectDeployments(String moduleName) {
            Set<String> deployments = new HashSet();

            for ((String deployment, AppInfo appInfo) : apps) {
                String name = appInfo.moduleName;
                if (name == moduleName) {
                    deployments += deployment;
                } else if (ModuleInfo moduleInfo := modules.get(name),
                    moduleInfo.dependsOn(moduleName)) {
                    deployments += deployment;
                }
            }

            return deployments;
        }
    }

    const UserInfo(UserId id, String name, String email) {

        UserInfo with(String? name = Null, String? email = Null) =
            new UserInfo(id, name ?: this.name, email ?: this.email);
    }

    enum ModuleType default(Generic) {Generic, Web, Db}
    const ModuleInfo(
            String           name,       // qualified
            Boolean          isResolved,
            ModuleType       moduleType,
            String[]         issues,
            RequiredModule[] dependencies
            ) {
        /**
         * @return True iff this module depends on the specified module
         */
        Boolean dependsOn(String moduleName) {
            return dependencies.any(rm -> rm.name == moduleName);
        }
    }

    const RequiredModule(
        String  name,      // qualified
        Boolean available);

    const InjectionKey(String name, String type);

    typedef Map<InjectionKey, String> as Injections;

    const AppInfo(
            String     deployment,          // the same module could be deployed multiple times
            String     moduleName,          // qualified module name
            Boolean    active     = False,  // if True, the app should be automatically started
            Injections injections = [],     // values for Destringable injection types
            ) {

        @Abstract
        AppInfo with(
            Boolean?    active     = Null,
            Injections? injections = Null);

        AppInfo updateStatus(Boolean active) {
            return active == this.active
                ? this
                : this.with(active=active);
        }

        AppInfo redact() = this;

        /**
         * Get an existing injection key for the given name and an optional type name.
         *
         * @return the existing key or an error message
         */
        InjectionKey|String findKey(String name, String type) {
            if (type == "") {
                InjectionKey? unique = Null;
                for (InjectionKey key : injections.keys) {
                    if (key.name == name) {
                        if (unique == Null) {
                            unique = key;
                        } else {
                            return $"Injection name {name.quoted()} is not unique";
                        }
                    }
                }
                return unique == Null
                        ? $"Invalid injection name: {name.quoted()}"
                        : unique;
            } else {
                InjectionKey key = new InjectionKey(name, type);
                return injections.contains(key)
                        ? key
                        : $"Invalid injection: \"{name}/{type}\"";
            }
        }
    }

    const WebAppInfo(
            String     deployment,          // @see AppInfo
            String     moduleName,          // @see AppInfo
            String     hostName,            // the full host name (e.g. "shop.acme.com.xqiz.it")
            String     password,            // an encrypted password to the keystore for this deployment
            String     provider   = "self", // the name of the certificate provider
            Boolean    active     = False,  // @see AppInfo
            Injections injections = [],     // @see AppInfo
            String[]   sharedDBs  = [],     // names of shared DB deployments
            )
            extends AppInfo(deployment, moduleName, active, injections) {

        @Override
        WebAppInfo with(
            Boolean?    active     = Null,
            Injections? injections = Null,
            String?     hostName   = Null,
            String?     password   = Null,
            String?     provider   = Null,
            String[]?   sharedDBs  = Null,
            ) {
            return new WebAppInfo(deployment, moduleName,
                hostName   ?: this.hostName,
                password   ?: this.password,
                provider   ?: this.provider,
                active     ?: this.active,
                injections ?: this.injections,
                sharedDBs  ?: this.sharedDBs,
                );
        }

        @Override
        WebAppInfo redact() = this.with(password="");
    }

    const DbAppInfo(
            String     deployment,         // @see AppInfo
            String     moduleName,         // @see AppInfo
            Boolean    active     = False, // @see AppInfo
            Injections injections = [],    // @see AppInfo
            )
            extends AppInfo(deployment, moduleName, active, injections) {

        @Override
        DbAppInfo with(
            Boolean?    active     = Null,
            Injections? injections = Null,
            ) {
            return new DbAppInfo(deployment, moduleName,
                active     ?: this.active,
                injections ?: this.injections
                );
        }
    }
}