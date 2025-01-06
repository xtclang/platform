import sec.Credential;
import sec.Entitlement;
import sec.Entity;
import sec.Group;
import sec.Permission;
import sec.Principal;
import sec.Subject;

import web.*;
import web.security.Authenticator;
import web.security.DigestCredential;

import webauth.AuthSchema;
import webauth.DBRealm;

import DigestCredential.Hash;
import DigestCredential.sha512_256;

/**
 * The `AuthEndPoint` is a [WebService] wrapper around an [Authenticator] that uses a [DBRealm].
 *
 * It provides out-the-box REST API to manage the underlying [auth database](AuthSchema).
 */
@WebService("/.well-known/auth")
@LoginRequired
@SessionRequired
service AuthEndpoint(WebApp app, Authenticator authenticator, DBRealm realm)
        implements Authenticator
        delegates Authenticator - Duplicable(authenticator) {

    @Override
    construct(AuthEndpoint that) {
        this.app           = that.app;
        this.authenticator = that.authenticator;
        this.realm         = that.realm;
    }

    /**
     * The AuthSchema db.
     */
    AuthSchema db.get() = realm.db;

    // ----- "self management" operations ----------------------------------------------------------

    /**
     * Retrieve the current user.
     */
    @Get("/profile")
    Principal getUser(Session session) = redact(session.principal?) : assert;

    /*
     * Change the password for the current user.
     *
     * The client must append "Base64(oldPassword):Base64(newPassword)" as a message body.
     */
    @Patch("/profile/password")
    HttpStatus changePassword(Session session, @BodyParam String passwords) {
        import convert.formats.Base64Format;

        assert Principal principal ?= session.principal;

        assert Int delim := passwords.indexOf(':');

        String b64Old = passwords[0 ..< delim];
        String b64New = passwords.substring(delim+1);

        String passwordOld = Base64Format.Instance.decode(b64Old).unpackUtf8();
        String passwordNew = Base64Format.Instance.decode(b64New).unpackUtf8();

        Hash hashOld = DigestCredential.passwordHash(principal.name, realm.name, passwordOld, sha512_256);

        Credential[] credentials = principal.credentials;
        FindOld: for (Credential credential : credentials) {
            if (credential.is(DigestCredential) &&
                    credential.matches(principal.name, hashOld)) {
                credentials = credentials.reify(Mutable);
                credentials[FindOld.count] =
                    credential.with(realmName=realm.name, password=passwordNew);
                credentials = credentials.toArray(Constant, inPlace=True);

                principal = realm.updatePrincipal(principal.with(credentials=credentials));
                session.authenticate(principal);
                return OK;
            }
        }
        return Conflict;
    }

    // ----- "user by id management" operations ----------------------------------------------------

    /**
     * Create a new user.
     */
    @Post("/users/{name}")
    @Restrict("MANAGE:/users")
    Principal|HttpStatus createUser(String name, @BodyParam String password) {
        try {
            Credential credential = new DigestCredential(realm.name, name, password);
            Principal  principal  = new Principal(0, name, credentials=[credential]);
            return redact(realm.createPrincipal(principal));
        } catch (Exception e) {
            return Conflict; // already exists
        }
    }

    /**
     * Retrieve the user by id.
     */
    @Get("/users/{userId}")
    @Restrict("GET:/users")
    Principal|HttpStatus getUser(Int userId) {
        if (Principal principal := realm.readPrincipal(userId)) {
            return redact(principal);
        }
        return NotFound;
    }

    /**
     * Retrieve the user by name.
     */
    @Get("/users?name={name}")
    @Restrict("GET:/users")
    Principal[] findUser(String name) {
        return realm.findPrincipals(p -> p.name == name)
                    .map(p -> redact(p))
                    .toArray(Constant);
    }

    /*
     * Change the password for the user.
     */
    @Patch("/users/{userId}/password")
    HttpStatus resetPassword(Int userId, @BodyParam String password) {
        if (userId == 0) {
             // only the root user can change its password and only via "changePassword"
            return Unauthorized;
        }

        using (db.connection.createTransaction()) {
            if (Principal principal := realm.readPrincipal(userId)) {
                Credential credential = new DigestCredential(realm.name, principal.name, password);
                realm.updatePrincipal(principal.with(credentials=[credential]));
                return OK;
            } else {
                return NotFound;
            }
        }
    }

    /**
     * Set permissions for the user.
     *
     * @param permText  comma-delimited list of permissions (e.g.: "GET:/,!*:/.well_known/auth")
     */
    @Post("/users/{userId}/permissions")
    @Restrict("MANAGE:/users")
    Principal|HttpStatus setUserPermission(Int userId, @BodyParam String permText) {
        if (userId == 0) {
            return Unauthorized; // cannot change the root user permissions
        }
        try {
            using (db.connection.createTransaction()) {
                if (Principal principal := realm.readPrincipal(userId)) {
                    principal = setPermissions(principal, permText);
                    realm.updatePrincipal(principal);
                    return redact(principal);
                } else {
                    return NotFound;
                }
            }
        } catch (Exception e) {
            return Conflict;
        }
    }

    /**
     * Add the user to the group.
     */
    @Post("/users/{userId}/groups/{groupId}")
    @Restrict("MANAGE:/users")
    Principal|HttpStatus addUserToGroup(Int userId, Int groupId) {
        using (db.connection.createTransaction()) {
            if (Principal principal := realm.readPrincipal(userId),
                                       realm.readGroup(groupId)) {
                if (addToGroup(principal, groupId)) {
                    realm.updatePrincipal(principal);
                }
                return redact(principal);
            }
        }
        return NotFound;
    }

    /**
     * Remove the user from the group.
     */
    @Delete("/users/{userId}/groups/{groupId}")
    @Restrict("MANAGE:/users")
    Principal|HttpStatus removeUserFromGroup(Int userId, Int groupId) {
        using (db.connection.createTransaction()) {
            if (Principal principal := realm.readPrincipal(userId),
                                       realm.readGroup(groupId)) {
                if (removeFromGroup(principal, groupId)) {
                    realm.updatePrincipal(principal);
                }
                return redact(principal);
            }
        }
        return NotFound;
    }

    /**
     * Delete the user.
     */
    @Delete("/users/{userId}")
    @Restrict("MANAGE:/users")
    HttpStatus deleteUser(Int userId) {
        if (userId == 0) {
            return Unauthorized; // cannot remove the root user
        }
        return realm.deletePrincipal(userId) ? OK : NotFound;
    }

    // ----- "group management" operations ---------------------------------------------------------

    /**
     * Create a new group.
     */
    @Post("/groups/{name}")
    @Restrict("MANAGE:/groups")
    Group|HttpStatus createGroup(String name) {
        try {
            Group group = realm.createGroup(new Group(0, name));
            return redact(group);
        } catch (Exception e) {
            return Conflict; // already exists
        }
    }

    /**
     * Retrieve the group by id.
     */
    @Get("/groups/{groupId}")
    @Restrict("GET:/groups")
    Group|HttpStatus getGroup(Int groupId) {
        if (Group group := realm.readGroup(groupId)) {
            return redact(group);
        }
        return NotFound;
    }

    /**
     * Retrieve the group by name.
     */
    @Get("/groups?name={name}")
    @Restrict("GET:/groups")
    Group[] findGroup(String name) {
        return realm.findGroups(g -> g.name == name)
                    .map(g -> redact(g))
                    .toArray(Constant);
    }

    /**
     * Set permissions for the group.
     *
     * @param permText  a comma-delimited list of permissions (e.g.: "GET:/,*:/.well_known")
     */
    @Post("/groups/{groupId}/permissions")
    @Restrict("MANAGE:/groups")
    Group|HttpStatus setGroupPermission(Int groupId, @BodyParam String permText) {
        try {
            using (db.connection.createTransaction()) {
                if (Group group := realm.readGroup(groupId)) {
                    group = setPermissions(group, permText);
                    realm.updateGroup(group);
                    return redact(group);
                } else {
                    return NotFound;
                }
            }
        } catch (Exception e) {
            return Conflict;
        }
    }

    /**
     * Add the group to another group.
     */
    @Post("/groups/{groupId}/group/{groupId2}")
    @Restrict("MANAGE:/groups")
    Group|HttpStatus addGroupToGroup(Int groupId, Int groupId2) {
        if (Group group := realm.readGroup(groupId),
                           realm.readGroup(groupId2)) {
            if (group := addToGroup(group, groupId2)) {
                realm.updateGroup(group);
            }
            return redact(group);
        } else {
            return NotFound;
        }
    }

    /**
     * Remove the group from another group.
     */
    @Delete("/groups/{groupId}/group/{groupId2}")
    @Restrict("MANAGE:/groups")
    Group|HttpStatus removeGroupFromGroup(Int groupId, Int groupId2) {
        if (Group group := realm.readGroup(groupId)) {
            if (group := removeFromGroup(group, groupId2)) {
                realm.updateGroup(group);
            }
            return redact(group);
        } else {
            return NotFound;
        }
    }

    /**
     * Delete the group.
     */
    @Delete("/groups/{groupId}")
    @Restrict("MANAGE:/groups")
    HttpStatus deleteGroup(Int groupId) {
        try {
            return realm.deleteGroup(groupId) ? OK : NotFound;
        } catch (Exception e) {
            return Conflict;
        }
    }

    // ----- helpers -------------------------------------------------------------------------------

    /**
     * Remove any information from the `Subject` that should not be passed to the client.
     */
    static <SubjectType extends Subject> SubjectType redact(SubjectType subject) {
        return subject.with(credentials=[]);
    }

    /**
     * Set permissions to the `Subject`.
     *
     * @param permText  comma-delimited array of permission strings
     *
     * @return the changed subject
     */
    static <SubjectType extends Subject> SubjectType setPermissions(
            SubjectType subject, String permText) {

        String[] permTexts = permText.split(',', omitEmpty=True, trim=True);
        if (permTexts.empty) {
            return subject.with(permissions=[]);
        }

        Permission[] permissions = permTexts.map(s -> new Permission(s)).toArray(Constant);
        return subject.with(permissions=permissions);
    }

    /**
     * Add the `Entity` to the group.
     *
     * @return True iff the entity has been changed
     * @return (optional) the changed entity
     */
    static <EntityType extends Entity> conditional EntityType addToGroup(
            EntityType entity, Int groupId) {

        Int[] groupIds = entity.groupIds;
        if (groupIds.contains(groupId)) {
            return False;
        } else {
            return True, entity.with(groupIds=groupIds + groupId);
        }
    }

    /**
     * Remove the `Entity` from the group.
     *
     * @return True iff the entity has been changed
     * @return (optional) the changed entity
     */
    static <EntityType extends Entity> conditional EntityType removeFromGroup(
            EntityType entity, Int groupId) {

        Int[] groupIds = entity.groupIds;
        if (groupIds := groupIds.removeIfPresent(groupId)) {
            return True, entity.with(groupIds=groupIds + groupId);
        } else {
            return False;
        }
    }
}
