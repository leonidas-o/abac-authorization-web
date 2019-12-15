import FluentPostgreSQL
import Foundation

final class UserRolePivot: PostgreSQLUUIDPivot {
    
    var id: UUID?
    var userID: User.ID
    var roleID: Role.ID
    
    typealias Left = User
    typealias Right = Role
    
    static let leftIDKey: LeftIDKey = \.userID
    static let rightIDKey: RightIDKey = \.roleID
    
    init(_ user: User, _ role: Role) throws {
        self.userID = try user.requireID()
        self.roleID = try role.requireID()
    }
}

extension UserRolePivot: ModifiablePivot {}
extension UserRolePivot: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.userID, to: \User.id, onDelete: .cascade)
        }
    }
}
