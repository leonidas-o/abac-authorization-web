import Vapor
import Foundation
import ABACAuthorization

/// Internal version of UserData contains a regular user
struct UserData: Codable {
    
    var user: User
    var roles: [Role]
    
    init(user: User, roles: [Role]) {
        self.user = user
        self.roles = roles
    }
    
    
    /// Public version of UserData contains a public user
    struct Public: Codable {
        
        var user: User.Public
        var roles: [Role]
        
        init(user: User.Public, roles: [Role]) {
            self.user = user
            self.roles = roles
        }
    }
    
}



// MARK: - General conformance

extension UserData: Content {}
extension UserData.Public: Content {}



// MARK: - General conversion

extension UserData {
    func convertToUserDataPublic() -> UserData.Public {
        return UserData.Public(user: user.convertToUserPublic(), roles: roles)
    }
}



// MARK: - ABACAuthorization

extension UserData: ABACUserData {
    public typealias ABACRoleType = Role
}

