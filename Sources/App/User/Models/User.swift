import Vapor
import Foundation

struct User: Codable {
    
    var id: UUID?
    var name: String
    var email: String
    var password: String
    var cachedAccessToken: String?
    
    
    init(id: UUID? = nil,
                name: String,
                email: String,
                password: String,
                cachedAccessToken: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.password = password
        self.cachedAccessToken = cachedAccessToken
    }
    
    
    struct Public: Codable {
        var id: UUID?
        var name: String
        var email: String
        
        
        init(id: UUID? = nil,
                    name: String,
                    email: String) {
            self.id = id
            self.name = name
            self.email = email
        }
    }
}



// MARK: - General conformace

extension User.Public: Content {}
extension User.Public: Authenticatable {}



// MARK: - General conversion

extension User {
    func convertToUserPublic() -> User.Public {
        return User.Public(id: id, name: name, email: email)
    }
}
