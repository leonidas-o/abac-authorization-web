import Vapor
import Fluent
import Foundation

struct UserPostgreSQLRepo: UserPersistenceRepo {
    
    let db: Database
    
    
    // MARK: - User
    
    func getAllUsersWithRoles() async throws -> [UserModel] {
        return try await UserModel.query(on: db).with(\.$roles).all()
    }
    
    
    func get(_ userId: UserModel.IDValue) async throws -> UserModel? {
        return try await UserModel.find(userId, on: db)
    }
    
    
    func getWithRoles(_ userId: UserModel.IDValue) async throws -> UserModel? {
        return try await UserModel.query(on: db).filter(\.$id == userId).with(\.$roles).first()
    }
    
    
    func get(byEmail email: String) async throws -> UserModel? {
        return try await UserModel.query(on: db).filter(\.$email == email).first()
    }
    
    
    func save(_ user: UserModel) async throws {
        return try await user.save(on: db)
    }
    
    
    func createUser(fromUserData userData: UserData) async throws -> UserModel {
        let user = userData.user.convertToUserModel()
        try await user.create(on: db)
        return user
    }
    
    func updateUser(fromUserData userData: UserData) async throws -> UserModel {
        guard userData.user.id != nil else {
            throw ModelError.idRequired
        }
        let user = userData.user.convertToUserModel()
        user.$id.exists = true
        try await user.update(on: db)
        return user
    }
    
    
    func updateUserInformation(_ user: UserModel, _ updatedUser: User.Public) async throws {
        
        user.name = updatedUser.name
        user.email = updatedUser.email
        // TODO: add all updateable properties
        
        return try await user.save(on: db)
    }

//    func update(_ user: User, _ updatedUser: User.Public) -> Future<UserData> {
//        return db.withConnection{ conn in
//
//            user.name = updatedUser.name
//            user.email = updatedUser.email
//            // TODO: add all updateable properties
//
//            return try map(to: UserData.self, user.save(on: conn), user.roles.query(on: conn).all()) { savedUser, roles in
//                return UserData(user: savedUser, roles: roles)
//            }
//        }
//    }
    
    
    func remove(_ user: UserModel) async throws {
        return try await user.delete(on: db)
    }
    
    
    func remove(_ userId: UserModel.IDValue) async throws {
        let user = try await UserModel.find(userId, on: db)
        guard let user = user else {
            return ()
        }
        return try await user.delete(on: db)
    }
    
    
    
    // MARK: - Role
    
    func addRole(_ role: RoleModel, to user: UserModel) async throws {
        return try await user.$roles.attach(role, on: db)
    }
    
    
    func getAllRoles(_ user: UserModel) async throws -> [RoleModel] {
        return try await user.$roles.query(on: db).all()
    }
    
    
    func getAllRoles(_ userId: UserModel.IDValue) async throws -> [RoleModel] {
        let user = try await UserModel.find(userId, on: db)
        guard let user = user else {
            return []
        }
        return try await user.$roles.query(on: db).all()
    }
    
    
    func removeRole(_ role: RoleModel, from user: UserModel) async throws {
        return try await user.$roles.detach(role, on: db)
    }
    
    
    func removeAllRoles(_ user: UserModel) async throws {
        return try await user.$roles.detach(user.roles, on: db)
    }
    
}
