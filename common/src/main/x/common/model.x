package model {
    typedef Int as AccountId;
    typedef Int as UserId;

    enum UserRole {Admin, Developer, Observer}

    const AccountInfo(AccountId id, String name,
                      Map<String, ModuleInfo> modules = [], // keyed by the fully qualified name
                      Map<String, WebAppInfo> webApps = [], // keyed by the deployment name
                      Map<UserId, UserRole>   users   = []
                      ) {

        AccountInfo addOrUpdateModule(ModuleInfo info) {
            return new AccountInfo(id, name, modules.put(info.name, info), webApps, users);
        }

        AccountInfo removeModule(String moduleName) {
            return new AccountInfo(id, name, modules.remove(moduleName), webApps, users);
        }

        AccountInfo addOrUpdateUser(UserId userId, UserRole role) {
            return new AccountInfo(id, name, modules, webApps, users.put(userId, role));
        }

        AccountInfo removeUser(UserId userId) {
            return new AccountInfo(id, name, modules, webApps, users.remove(userId));
        }

        AccountInfo addOrUpdateWebApp(WebAppInfo info) {
            return new AccountInfo(id, name, modules, webApps.put(info.deployment, info), users);
        }

        AccountInfo removeWebApp(String deployment) {
            return new AccountInfo(id, name, modules, webApps.remove(deployment), users);
        }

        /**
         * @return the name of deployments that depend on the specified module(s)
         */
        Set<String> collectDeployments(String moduleName) {
            Set<String> deployments = new HashSet();

            for ((String deployment, WebAppInfo webAppInfo) : webApps) {
                String webModuleName = webAppInfo.moduleName;
                if (webModuleName == moduleName) {
                    deployments += deployment;
                } else if (ModuleInfo moduleInfo := modules.get(webModuleName),
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

    const WebAppInfo(
            String     deployment,          // the same module could be deployed multiple times
            String     moduleName,          // qualified
            String     hostName,            // the full host name (e.g. "shop.acme.com.xqiz.it")
            String     password,            // an encrypted password to the keystore for this deployment
            String     provider   = "self", // the name of the certificate provider
            Boolean    active     = False,  // if Treu, the app should be automatically started
            Injections injections = [],     // values for Destringable injection types
            ) {

        WebAppInfo with(
            String?     hostName   = Null,
            String?     password   = Null,
            String?     provider   = Null,
            Boolean?    active     = Null,
            Injections? injections = Null) {

            return new WebAppInfo(deployment, moduleName,
                hostName   ?: this.hostName,
                password   ?: this.password,
                provider   ?: this.provider,
                active     ?: this.active,
                injections ?: this.injections);
        }

        WebAppInfo updateStatus(Boolean active) {
            return active == this.active
                ? this
                : this.with(active=active);
        }

        WebAppInfo redact() {
            return this.with(password="");
        }

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
}