import ecstasy.maps.CollectImmutableMap;

package model {
    typedef Int as AccountId;
    typedef Int as UserId;

    const AccountInfo(AccountId id, String name,
                      Map<String, ModuleInfo> modules = [], // keyed by the fully qualified name
                      Map<String, AppInfo>    apps    = [], // keyed by the deployment name
                      UserId[]                users   = []
                      ) {

        AccountInfo addOrUpdateModule(ModuleInfo info) {
            return new AccountInfo(id, name, modules.put(info.name, info), apps, users);
        }

        AccountInfo removeModule(String moduleName) {
            return new AccountInfo(id, name, modules.remove(moduleName), apps, users);
        }

        AccountInfo addOrUpdateUser(UserId userId) {
            if (UserId[] users := this.users.addIfAbsent(userId)) {
                return new AccountInfo(id, name, modules, apps, users);
            }
            return this;
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

    enum ModuleKind default(Generic) {Generic, Web, Db}
    const ModuleInfo(
            String           name,       // qualified
            Boolean          resolved,
            Time             uploaded,
            ModuleKind       kind,
            String[]         issues,
            RequiredModule[] dependencies,
            InjectionKey[]   injections,
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

    /**
     * Injection key is used to store custom (Destringable) injection values.
     */
    const InjectionKey(String name, String type);

    /**
     * Identity Provider info contains encoded clientId and clientSecret
     */
    const IdpInfo(String clientId, String clientSecret) {
        assert() {
            assert clientSecret.size > 8 as "inadequate secret length";
        }

        IdpInfo redact() = new IdpInfo(clientId,
                                $|{"*".dup(10)}{clientSecret.substring(-6)}
                                );
    }

    typedef Map<InjectionKey, String> as Injections;
    typedef Map<String, IdpInfo> as IdpInfos;

    const AppInfo(
            String  deployment,          // the same module could be deployed multiple times
            String  moduleName,          // qualified module name
            Boolean autoStart  = False,  // if True, the app should be automatically started
            Boolean active     = False,  // if True, the app is currently active; this flag is
                                         // transient and is here only to simplify communications
                                         // withe the UI
            Injections injections = [],  // values for Destringable injection types
            ) {

        @Abstract
        AppInfo with(
            Boolean?    autoStart  = Null,
            Boolean?    active     = Null,
            Injections? injections = Null,
            );

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
            String     deployment,           // @see AppInfo
            String     moduleName,           // @see AppInfo
            String     hostName,             // the full host name (e.g. "shop.acme.com.xqiz.it")
            String     password,             // an encrypted password to the keystore for this deployment
            String     provider    = "self", // the name of the certificate provider
            Boolean    autoStart   = False,  // @see AppInfo
            Boolean    active      = False,  // @see AppInfo
            Injections injections  = [],     // @see AppInfo
            String[]   sharedDBs   = [],     // names of shared DB deployments
            Boolean    useCookies  = True,   // use CookieBroker as a session broker
            Boolean    useAuth     = False,  // use DBRealm for authentication
            IdpInfos   idProviders = [],     // IdentityProvider (via OAuth) info by provider
            )
            extends AppInfo(deployment, moduleName, autoStart, active, injections) {

        @Override
        WebAppInfo with(
            Boolean?    autoStart   = Null,
            Boolean?    active      = Null,
            Injections? injections  = Null,
            String?     hostName    = Null,
            String?     password    = Null,
            String?     provider    = Null,
            String[]?   sharedDBs   = Null,
            Boolean?    useCookies  = Null,
            Boolean?    useAuth     = Null,
            IdpInfos?   idProviders = Null,
            ) {
            return new WebAppInfo(deployment, moduleName,
                hostName    ?: this.hostName,
                password    ?: this.password,
                provider    ?: this.provider,
                autoStart   ?: this.autoStart,
                active      ?: this.active,
                injections  ?: this.injections,
                sharedDBs   ?: this.sharedDBs,
                useCookies  ?: this.useCookies,
                useAuth     ?: this.useAuth,
                idProviders ?: this.idProviders,
                );
        }

        @Override
        WebAppInfo redact() = this.with(password="")
                                  .with(idProviders=idProviders.map(e ->
                                      e.value.redact(), new CollectImmutableMap<String, IdpInfo>()));
    }

    const DbAppInfo(
            String     deployment,         // @see AppInfo
            String     moduleName,         // @see AppInfo
            Boolean    autoStart  = False, // @see AppInfo
            Boolean    active     = False, // @see AppInfo
            Injections injections = [],    // @see AppInfo
            )
            extends AppInfo(deployment, moduleName, autoStart, active, injections) {

        @Override
        DbAppInfo with(
            Boolean?    autoStart  = Null,
            Boolean?    active     = Null,
            Injections? injections = Null,
            ) {
            return new DbAppInfo(deployment, moduleName,
                autoStart  ?: this.autoStart,
                active     ?: this.active,
                injections ?: this.injections,
                );
        }
    }
}