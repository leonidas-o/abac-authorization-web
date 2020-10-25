import Fluent
import Foundation


final class UserRolePivot: Model {
    
    static let schema = "user_role_pivot"
    
    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: UserModel
    @Parent(key: "role_id") var role: RoleModel

    init() {}
    
    init(id: UUID? = nil, user: UserModel, role: RoleModel) throws {
        self.id = id
        self.$user.id = try user.requireID()
        self.$role.id = try role.requireID()
    }
    
}



// MARK: - Migration

struct UserRolePivotMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_role_pivot")
            .id()
            .field("user_id", .uuid, .required, .references("user", "id", onDelete: .cascade))
            .field("role_id", .int, .required, .references("role", "id", onDelete: .cascade))
            .unique(on: "user_id", "role_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_role_pivot")
            .delete()
    }
}
