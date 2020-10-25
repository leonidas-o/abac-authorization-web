import Vapor
import Fluent
import Foundation

struct UserPostgreSQLRepo: UserPersistenceRepo {
    
    let db: Database
    
    
    // MARK: - User
    
    func getAllUsersWithRoles() -> EventLoopFuture<[UserModel]> {
        return UserModel.query(on: db).with(\.$roles).all()
    }
    
    
    func get(_ userId: UserModel.IDValue) -> EventLoopFuture<UserModel?> {
        return UserModel.find(userId, on: db)
    }
    
    
    func getWithRoles(_ userId: UserModel.IDValue) -> EventLoopFuture<UserModel?> {
        return UserModel.query(on: db).filter(\.$id == userId).with(\.$roles).first()
    }
    
    
    func get(byEmail email: String) -> EventLoopFuture<UserModel?> {
        return UserModel.query(on: db).filter(\.$email == email).first()
    }
    
    
    func save(_ user: UserModel) -> EventLoopFuture<Void> {
        return user.save(on: db)
    }
    
    
    func createUser(fromUserData userData: UserData) -> EventLoopFuture<UserModel> {
        let user = userData.user.convertToUserModel()
        return user.create(on: db)
            .transform(to: user)
    }
    
    func updateUser(fromUserData userData: UserData) -> EventLoopFuture<UserModel> {
        guard userData.user.id != nil else {
            return db.eventLoop.makeFailedFuture(ModelError.idRequired)
        }
        let user = userData.user.convertToUserModel()
        user.$id.exists = true
        return user.update(on: db)
            .transform(to: user)
    }
    
    
    func updateUserInformation(_ user: UserModel, _ updatedUser: User.Public) -> EventLoopFuture<Void> {
        
        user.name = updatedUser.name
        user.email = updatedUser.email
        // TODO: add all updateable properties
        
        return user.save(on: db)
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
    
    
    func remove(_ user: UserModel) -> EventLoopFuture<Void> {
        return user.delete(on: db)
    }
    
    
    func remove(_ userId: UserModel.IDValue) -> EventLoopFuture<Void> {
        return UserModel.find(userId, on: db).flatMap { user in
            guard let user = user else {
                return db.eventLoop.makeSucceededFuture(())
            }
            return user.delete(on: db)
        }
    }
    
    
    
    // MARK: - Role
    
    func addRole(_ role: RoleModel, to user: UserModel) -> EventLoopFuture<Void> {
        return user.$roles.attach(role, on: db)
    }
    
    
    func getAllRoles(_ user: UserModel) -> EventLoopFuture<[RoleModel]> {
        return user.$roles.query(on: db).all()
    }
    
    
    func getAllRoles(_ userId: UserModel.IDValue) -> EventLoopFuture<[RoleModel]> {
        return UserModel.find(userId, on: db).flatMap { user in
            guard let user = user else {
                return db.eventLoop.makeSucceededFuture([])
            }
            return user.$roles.query(on: db).all()
        }
    }
    
    
    func removeRole(_ role: RoleModel, from user: UserModel) -> EventLoopFuture<Void> {
        return user.$roles.detach(role, on: db)
    }
    
    
    func removeAllRoles(_ user: UserModel) -> EventLoopFuture<Void> {
        return user.$roles.detach(user.roles, on: db)
    }
    
}
