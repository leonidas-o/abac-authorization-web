import Vapor
import Fluent

struct RolePostgreSQLRepo: RolePersistenceRepo {
    
    let db: Database
    
    
    func getAll() async throws -> [RoleModel] {
        return try await RoleModel.query(on: db).all()
    }
    
    
    func get(_ role: RoleModel) async throws -> RoleModel? {
        if let roleId = role.id {
            return try await get(roleId)
        } else {
            return nil
        }
    }
    
    
    func get(_ roleId: RoleModel.IDValue) async throws -> RoleModel? {
        return try await RoleModel.find(roleId, on: db)
    }
    
    
    func _getAllUsersFor(_ role: RoleModel) async throws -> [UserModel] {
        return try await role.$users.query(on: db).all()
    }
    
    
    func save(_ role: RoleModel) async throws {
        return try await role.save(on: db)
    }
    
    
    func update(_ role: RoleModel, _ updatedRole: Role) async throws {
        role.name = updatedRole.name
        return try await role.save(on: db)
    }
    
    
    func delete(_ roleId: RoleModel.IDValue) async throws {
        return try await RoleModel.query(on: db).filter(\.$id == roleId).delete()
    }
    
    
    func delete(_ role: RoleModel) async throws {
        return try await role.delete(on: db)
    }
    
}
