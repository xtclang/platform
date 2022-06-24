package model
    {
    typedef UInt as AccountId;
    typedef UInt as UserId;

    enum UserRole {Admin, Developer, Observer}

    const AccountInfo(AccountId id, String name,
                      Map<String, ModuleInfo> modules = [],
                      Map<UserId, UserRole>   users   = []
                      )
        {
        AccountInfo addModule(ModuleInfo info)
            {
            return new AccountInfo(id, name, modules.put(info.name, info), users);
            }
        AccountInfo addUser(UserId idUser, UserRole role)
            {
            return new AccountInfo(id, name, modules, users.put(idUser, role));
            }
        }

    const AccountUser(UserId idUser, AccountId idAccount)
        {
        }

    const UserInfo(UserId id, String name, String email)
        {
        }

    enum ModuleStyle {Generic, WebApp, DB}

    const ModuleInfo(String name, ModuleStyle style, String? domain = Null)
        {
        }
    }