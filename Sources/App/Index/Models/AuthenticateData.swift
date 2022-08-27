import Foundation
import Vapor

struct AuthenticateData: Codable {
    let id: UUID?
    let token: String
    
    init(id: UUID? = nil, token: String) {
        self.id = id
        self.token = token
    }
    
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }
}


extension AuthenticateData: Content {}
