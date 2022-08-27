import Vapor
import Fluent

struct AdminUserMigration: AsyncMigration {
    
    enum Constant {
        static let name = "Admin"
        static let email = "webmaster@foo.com"
        static let passwordLength = 16
    }
    
    func prepare(on database: Database) async throws {
        let random = [UInt8].random(count: Constant.passwordLength).base64
        print("\nPASSWORD: \(random)")
        let password = try? Bcrypt.hash(random)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        
        let user = UserModel(name: Constant.name,
                             email: Constant.email,
                             password: hashedPassword)
        return try await user.save(on: database)
    }
    
    func revert(on database: Database) async throws {
        try await UserModel.query(on: database).filter(\.$email == Constant.email)
            .delete()
    }
    
}
