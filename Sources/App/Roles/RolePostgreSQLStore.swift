import Vapor
import FluentPostgreSQL
import Foundation

final class RolePostgreSQLStore: RolePersistenceStore {
    
    let db: PostgreSQLDatabase.ConnectionPool
    
    init(_ db: PostgreSQLDatabase.ConnectionPool) {
        self.db = db
    }
    
    func getAll() -> EventLoopFuture<APIRoleResponse> {
        return db.withConnection{ conn in
            return Role.query(on: conn).all().map{ roles in
                return APIRoleResponse(type: .full, source: roles)
            }
        }
    }
    
    func _getAllUsersFor(_ role: Role) -> EventLoopFuture<[User]> {
        return db.withConnection{ conn in
            return try role.users.query(on: conn).all()
        }
    }
    
    func save(_ role: Role) -> EventLoopFuture<APIRoleResponse> {
        return db.withConnection{ conn in
            return role.save(on: conn).map{ savedRole in
                return APIRoleResponse(type: .one, source: [savedRole])
            }
        }
    }
    
    func update(_ role: Role, _ updatedRole: Role) -> EventLoopFuture<APIRoleResponse> {
        return db.withConnection{ conn in
            role.name = updatedRole.name
            return role.save(on: conn).map{ savedRole in
                return APIRoleResponse(type: .one, source: [savedRole])
            }
        }
    }
    
    func delete(_ role: Role) -> EventLoopFuture<Void> {
        return db.withConnection{ conn in
            return role.delete(on: conn)
        }
    }
    
}




//MARK: - ServiceType conformance

extension RolePostgreSQLStore {
    static let serviceSupports: [Any.Type] = [RolePersistenceStore.self]
    
    static func makeService(for worker: Container) throws -> Self {
        return .init(try worker.connectionPool(to: .psql))
    }
}
