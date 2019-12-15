import Foundation
import ABACAuthorization
import Vapor


/// Internal version of UserData contains a regular user
public struct UserData: Codable {
    
    var user: User
    public var roles: [Role]
    
    init(user: User, roles: [Role]) {
        self.user = user
        self.roles = roles
    }
}

/// API version of UserData contains a public user
public struct APIUserData: Codable {
    
    var user: User.Public
    public var roles: [Role]
    
    init(user: User.Public, roles: [Role]) {
        self.user = user
        self.roles = roles
    }
}

extension UserData: Content {}
extension APIUserData: Content {}

extension UserData: ABACUserData {
    public typealias ABACRoleType = Role
}

