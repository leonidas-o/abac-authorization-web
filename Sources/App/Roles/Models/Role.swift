import Vapor
import FluentPostgreSQL
import Foundation
import ABACAuthorization

public final class Role: Codable {
    public var id: Int?
    public var name: String
    
    public init(name: String) {
        self.name = name
    }
}

extension Role: PostgreSQLModel {}
extension Role: Parameter {}

extension Role {
    var users: Siblings<Role, User, UserRolePivot> {
        return siblings()
    }
}

extension Role: Equatable {
    public static func == (lhs: Role, rhs: Role) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Role: Migration {
    public static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.name)
        }
    }
}

struct AdminRole: Migration {
    typealias Database = PostgreSQLDatabase
    
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        let role = Role(name: "admin")
        return role.save(on: connection).flatMap(to: Void.self) { role in
            return User.query(on: connection).all().flatMap(to: [User].self) { users in
                if users.count == 1 && users[0].email == AdminUser.Constant.email {
                    return users.first!.roles.attach(role, on: connection).map(to: [User].self) { _ in
                        return users
                    }
                } else {
                    return connection.future(users)
                }
            }.transform(to: ())
        }
    }
    
    static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return .done(on: connection)
    }
}

extension Role: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Role: ABACRole {}
