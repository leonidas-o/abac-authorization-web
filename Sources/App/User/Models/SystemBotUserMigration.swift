import Vapor
import Fluent

struct SystemBotUserMigration: Migration {
    
    enum Constant {
        static let name = "SystemBot"
        static let email = "systembot@foo.com"
        static let passwordLength = 16
    }
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let random = [UInt8].random(count: Constant.passwordLength).base64
        let password = try? Bcrypt.hash(random)
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        
        let user = UserModel(name: Constant.name,
                             email: Constant.email,
                             password: hashedPassword)
        return user.save(on: database)
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        UserModel.query(on: database).filter(\.$email == Constant.email)
            .delete()
    }
    
}
