import Vapor
import Fluent

struct DefaultRolesMigration: AsyncMigration {
    
    enum DefaultRole: String {
        case admin = "admin"
        case systemBot = "system-bot"
        // more roles can be added
    }
    
    private let defaultRoles = [
        RoleModel(name: DefaultRole.admin.rawValue),
        RoleModel(name: DefaultRole.systemBot.rawValue),
    ]
    
    func prepare(on database: Database) async throws {
        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for role in defaultRoles {
                taskGroup.addTask { try await role.save(on: database) }
            }
        }
        
        // Admin role to user
        guard let adminUser = try await UserModel.query(on: database).filter(\.$email == AdminUserMigration.Constant.email).first(),
              let adminRole = defaultRoles.first(where: { $0.name == DefaultRole.admin.rawValue }) else {
            throw ModelError.migrationFailed(reason: "Check admin-user and default admin-role")
        }
        try await adminUser.$roles.attach(adminRole, on: database)

        // SystemBot role to user
        guard let botUser = try await UserModel.query(on: database).filter(\.$email == SystemBotUserMigration.Constant.email).first(),
              let botRole = defaultRoles.first(where: { $0.name == DefaultRole.systemBot.rawValue }) else {
            throw ModelError.migrationFailed(reason: "Check SystemBot-user and default SystemBot-role")
        }
        return try await botUser.$roles.attach(botRole, on: database)
    }
    
    func revert(on database: Database) async throws {
        try await RoleModel.query(on: database).filter(\.$name ~~ defaultRoles.map { $0.name } ).delete()
    }
}
