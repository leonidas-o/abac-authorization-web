import Authentication
import FluentPostgreSQL
import Vapor

protocol UserDefinition {
    var id: UUID? { get set }
    var name: String { get set }
    var email: String { get set }
    var password: String { get set }
    
    func convertToPublic() -> User.Public
}

final class User: PostgreSQLUUIDModel {
    var id: UUID?
    var name: String
    var email: String
    var password: String

    init(id: UUID? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.password = passwordHash
    }
    
    final class Public: Codable {

        var id: UUID?
        var name: String
        var email: String

        init(id: UUID? = nil, name: String, email: String) {
            self.id = id
            self.name = name
            self.email = email
        }
    }
    
}


extension User: BasicAuthenticatable {
    static var usernameKey: UsernameKey = \User.email
    static var passwordKey: PasswordKey = \User.password
}

/// Allows users to be verified by bearer / token auth middleware.
extension User: TokenAuthenticatable {
    /// See `TokenAuthenticatable`.
    typealias TokenType = AccessData
    
    static func authenticate(token: AccessData, on connection: DatabaseConnectable) -> EventLoopFuture<User?> {
        return connection.future(token.userData.user)
    }
}

/// Allows `User` to be used as a Fluent migration.
extension User: Migration {
    /// See `Migration`.
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(User.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.name)
            builder.field(for: \.email)
            builder.field(for: \.password)
            builder.unique(on: \.email)
        }
    }
}

/// Allows `User` to be encoded to and decoded from HTTP messages.
extension User: Content {}

/// Allows `User` to be used as a dynamic parameter in route definitions.
extension User: Parameter {}

extension User: UserDefinition {}

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: id, name: name, email: email)
    }
}


extension User: SessionAuthenticatable {}
