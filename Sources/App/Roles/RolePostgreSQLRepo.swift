import Vapor
import Fluent


struct RolePostgreSQLRepo: RolePersistenceRepo {
    
    let db: Database
    
    
    func getAll() -> EventLoopFuture<[RoleModel]> {
        return RoleModel.query(on: db).all()
    }
    
    
    func get(_ role: RoleModel) -> EventLoopFuture<RoleModel?> {
        if let roleId = role.id {
            return get(roleId)
        } else {
            return db.eventLoop.makeSucceededFuture(nil)
        }
    }
    
    
    func get(_ roleId: RoleModel.IDValue) -> EventLoopFuture<RoleModel?> {
        return RoleModel.find(roleId, on: db)
    }
    
    
    func _getAllUsersFor(_ role: RoleModel) -> EventLoopFuture<[UserModel]> {
        return role.$users.query(on: db).all()
    }
    
    
    func save(_ role: RoleModel) -> EventLoopFuture<Void> {
        return role.save(on: db)
    }
    
    
    func update(_ role: RoleModel, _ updatedRole: Role) -> EventLoopFuture<Void> {
        role.name = updatedRole.name
        return role.save(on: db)
    }
    
    
    func delete(_ roleId: RoleModel.IDValue) -> EventLoopFuture<Void> {
        return RoleModel.query(on: db).filter(\.$id == roleId).delete()
    }
    
    
    func delete(_ role: RoleModel) -> EventLoopFuture<Void> {
        return role.delete(on: db)
    }
    
}
