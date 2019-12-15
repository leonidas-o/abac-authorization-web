import Vapor
import FluentPostgreSQL
import Foundation

final class UserPostgreSQLStore: UserPersistenceStore {
    
    let db: PostgreSQLDatabase.ConnectionPool
    
    init(_ db: PostgreSQLDatabase.ConnectionPool) {
        self.db = db
    }
    
    
    
    // MARK: - User
    
    func getAllUsers() -> Future<APIUserResponse> {
        return db.withConnection{ conn in
            return conn.raw("""
            SELECT "User".*, ARRAY_REMOVE(ARRAY_AGG("Role"."name"), NULL) AS "roles" FROM "User"
            JOIN "Role_User" ON "User"."id" = "Role_User"."userID"
            JOIN "Role" ON "Role"."id" = "Role_User"."roleID"
            GROUP BY "User"."id";
            """).all(decoding: UserRoleAgg.self).map{ userRoleAggCollection in
                let apiUserDataCollection = userRoleAggCollection.map{ userRoleAgg -> APIUserData in
                    let userPublic = userRoleAgg.convertToPublic()
                    let roles = userRoleAgg.roles.map{ Role(name: $0) }
                    return APIUserData(user: userPublic, roles: roles)
                }
                return APIUserResponse(type: .full, source: apiUserDataCollection)
            }
        }
    }
    
    
    func _get(_ user: User) -> Future<User?> {
        return db.withConnection { conn in
            guard let id = user.id else { throw Abort(.internalServerError) }
            return User.find(id, on: conn)
        }
    }
    
    func get(_ user: User) -> Future<APIUserResponse> {
        return db.withConnection{ conn in
            return try user.roles.query(on: conn).all().map{ roles in
                return APIUserData(user: user.convertToPublic(), roles: roles)
            }.map{ apiUserData in
                return APIUserResponse(type: .one, source: [apiUserData])
            }
        }
    }
    
    func _save(_ user: User) -> Future<User> {
        return db.withConnection{ conn in
            user.save(on: conn)
        }
    }
    
    func save(_ userData: UserData) -> Future<User> {
        return db.withConnection{ conn in
            
            return userData.user.save(on: conn).flatMap{ user in
                var roleSaveResult: [Future<UserRolePivot>] = []
                for role in userData.roles {
                    roleSaveResult.append(user.roles.attach(role, on: conn))
                }
                return roleSaveResult.flatten(on: conn).transform(to: user)
            }
            
        }
    }

    func update(_ user: User, _ updatedUser: User.Public) -> Future<UserData> {
        return db.withConnection{ conn in
            
            user.name = updatedUser.name
            user.email = updatedUser.email
            // TODO: add all updateable properties
            
            return try map(to: UserData.self, user.save(on: conn), user.roles.query(on: conn).all()) { savedUser, roles in
                return UserData(user: savedUser, roles: roles)
            }
        }
    }
    
    func update(_ user: User, _ updatedUserData: APIUserData) -> Future<UserData> {
        return db.withConnection{ conn in

            user.name = updatedUserData.user.name
            user.email = updatedUserData.user.email
            // TODO: add other properties

            return try flatMap(to: UserData.self, user.save(on: conn), user.roles.query(on: conn).sort(\.name, .ascending).all()) { savedUser, oldRoles in

                let newRoles = updatedUserData.roles.sorted { $0.name < $1.name }
                if oldRoles != newRoles {

                    return savedUser.roles.detachAll(on: conn).flatMap(to: UserData.self) { _ in
                        var roleSaveResult: [Future<UserRolePivot>] = []
                        for role in newRoles {
                            roleSaveResult.append(savedUser.roles.attach(role, on: conn))
                        }
                        return roleSaveResult.flatten(on: conn).transform(to: UserData(user: savedUser, roles: newRoles))
                    }
                } else {
                    return conn.future(UserData(user: savedUser, roles: oldRoles))
                }
            }
        }
    }
    
    func delete(_ user: User) -> Future<Void> {
        return db.withConnection{ conn in
            return user.delete(on: conn)
        }
    }
    
    
    
    // MARK: - Role
    
    func addRole(_ role: Role, to user: User) -> Future<HTTPStatus> {
        return db.withConnection{ conn in
            return user.roles.attach(role, on: conn).transform(to: .created)
        }
    }
    
    func getAllRoles() -> Future<APIRoleResponse> {
        return db.withConnection{ conn in
            return Role.query(on: conn).all().map{ roles in
                return APIRoleResponse(type: .full, source: roles)
            }
        }
    }
    
    func getAllRoles(from user: User) -> Future<APIRoleResponse> {
        return db.withConnection{ conn in
            return try user.roles.query(on: conn).all().map{ roles in
                return APIRoleResponse(type: .partial, source: roles)
            }
        }
    }

    func removeRole(_ role: Role, from user: User) -> Future<HTTPStatus> {
        return db.withConnection{ conn in
            return user.roles.detach(role, on: conn).transform(to: .noContent)
        }
    }
    
    func removeAllRoles(from user: User) -> Future<HTTPStatus> {
        return db.withConnection{ conn in
            return user.roles.detachAll(on: conn).transform(to: .noContent)
        }
    }
    
}




extension UserPostgreSQLStore {
    static func makeService(for container: Container) throws -> Self {
        return .init(try container.connectionPool(to: .psql))
    }
}


extension UserPostgreSQLStore {

    struct UserRoleAgg: Decodable, UserDefinition {
        var id: UUID?
        var name: String
        var email: String
        var password: String
        var roles: [String]
        
        func convertToPublic() -> User.Public {
            return User.Public(id: id, name: name, email: email)
        }

    }
    
}
