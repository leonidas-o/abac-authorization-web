import Vapor
import Fluent


struct DefaultRolesMigration: Migration {
    
    enum DefaultRole: String {
        case admin = "admin"
        case systemBot = "system-bot"
        // more roles can be added
    }
    
    private let defaultRoles = [
        RoleModel(name: DefaultRole.admin.rawValue),
        RoleModel(name: DefaultRole.systemBot.rawValue),
    ]
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return defaultRoles.map { $0.save(on: database) }.flatten(on: database.eventLoop).flatMap {
            // Admin role to user
            return UserModel.query(on: database).filter(\.$email == AdminUserMigration.Constant.email).first().flatMap { user in
                if let adminUser = user, let adminRole = defaultRoles.first(where: { $0.name == DefaultRole.admin.rawValue }) {
                    return adminUser.$roles.attach(adminRole, on: database)
                } else {
                    return database.eventLoop.makeFailedFuture(ModelError.migrationFailed(reason: "Check admin-user and default admin-role"))
                }
            }
        }.flatMap {
            // SystemBot role to user
            return UserModel.query(on: database).filter(\.$email == SystemBotUserMigration.Constant.email).first().flatMap { user in
                if let botUser = user, let botRole = defaultRoles.first(where: { $0.name == DefaultRole.systemBot.rawValue }) {
                    return botUser.$roles.attach(botRole, on: database)
                } else {
                    return database.eventLoop.makeFailedFuture(ModelError.migrationFailed(reason: "Check SystemBot-user and default SystemBot-role"))
                }
            }
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        RoleModel.query(on: database).filter(\.$name ~~ defaultRoles.map { $0.name } ).delete()
    }
}
