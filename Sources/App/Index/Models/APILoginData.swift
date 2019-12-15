import Vapor
import Foundation

struct APILoginData: Codable {
    let username: String
    let password: String
    
    func encode() -> APILoginData {
        guard let encodedUsername = self.username.data(using: .utf8)?.base64EncodedString(), let encodedPassword = self.password.data(using: .utf8)?.base64EncodedString() else {
            fatalError()
        }
        return APILoginData(username: encodedUsername, password: encodedPassword)
    }
}

extension APILoginData: Content {}
