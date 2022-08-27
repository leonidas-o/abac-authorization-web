import Vapor
import Fluent
import Foundation
import ABACAuthorization

final class RoleModel: Model {
    
    static let schema = "role"
    
    @ID(custom: .id) var id: Int?
    @Field(key: "name") var name: String
    
    // Siblings
    @Siblings(through: UserRolePivot.self, from: \.$role, to: \.$user) public var users: [UserModel]
    
    
    init() {}
    
    init(id: Int? = nil, name: String) {
        self.id = id
        self.name = name
    }
}



// MARK: - General extensions

extension RoleModel: Content {}



// MARK: - DTO conversion

extension RoleModel {
    func convertToRole() -> Role {
        return Role(id: id,
                    name: name)
    }
}


extension Role {
    func convertToRoleModel() -> RoleModel {
        return RoleModel(id: id,
                         name: name)
    }
}



// MARK: - Migrations

struct RoleModelMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("role")
        .field(.id, .int, .identifier(auto: true), .required)
        .field("name", .string, .required)
        .unique(on: "name")
        .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("role")
        .delete()
    }
}



// MARK: - ABACAuthorization

extension RoleModel: ABACRole {}
extension Role: ABACRole {}
