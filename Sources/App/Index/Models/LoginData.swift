import Vapor
import Foundation

struct LoginData: Codable {
    let username: String
    let password: String
    
    func encode() -> LoginData {
        guard let encodedUsername = self.username.data(using: .utf8)?.base64EncodedString(), let encodedPassword = self.password.data(using: .utf8)?.base64EncodedString() else {
            fatalError()
        }
        return LoginData(username: encodedUsername, password: encodedPassword)
    }
}

extension LoginData: Content {}
