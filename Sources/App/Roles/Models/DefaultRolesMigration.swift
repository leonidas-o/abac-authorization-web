import Vapor
import Fluent


struct DefaultRolesMigration: Migration {
    
    enum DefaultRole: String {
        case admin = "admin"
        // more roles can be added
    }
    
    private let defaultRoles = [
        RoleModel(name: DefaultRole.admin.rawValue)
    ]
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        
        defaultRoles.map { $0.save(on: database) }.flatten(on: database.eventLoop).flatMap {
            
            UserModel.query(on: database).filter(\.$email == AdminUserMigration.Constant.email).first().flatMap { user in
                
                if let adminUser = user, let adminRole = defaultRoles.first(where: { $0.name == DefaultRole.admin.rawValue }) {
                    return adminUser.$roles.attach(adminRole, on: database)
                } else {
                    return database.eventLoop.makeFailedFuture(ModelError.migrationFailed(reason: "Check admin-user and default admin-role"))
                }
            }
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        RoleModel.query(on: database).filter(\.$name ~~ defaultRoles.map { $0.name } ).delete()
    }
}
