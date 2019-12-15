import Foundation
import FluentPostgreSQL
import Crypto
import ABACAuthorization

struct AdminUser: Migration {
    typealias Database = PostgreSQLDatabase
    
    enum Constant {
        static let firstName = "Admin"
        static let lastName = "Admin"
        static let additionalName = "Admin"
        static let email = "webmaster@foo.com"
    }
    
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        let randomPassword = (try? CryptoRandom().generateData(count: 16).base64EncodedString())!
        print("\nPASSWORD: \(randomPassword)") // TODO: use logger
        let password = try? BCrypt.hash(randomPassword)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        let user = User(
            name: Constant.lastName,
            email: Constant.email,
            passwordHash: hashedPassword)
        return user.save(on: connection).transform(to: ())
    }
    
    static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return .done(on: connection)
    }
}

extension User {
    var roles: Siblings<User, Role, UserRolePivot> {
        return siblings()
    }
}

extension User: ABACUser {}
