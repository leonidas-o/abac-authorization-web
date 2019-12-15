import Foundation
import ABACAuthorization

public struct APIResource {
    public var apiEntry: String = "api"
    public var all: [String] = Resource.allCases.map{$0.rawValue}

    /// API resources (also pivot tables)
    public enum Resource: String, CaseIterable {
        case login = "login"
        case authorizationPolicy = "authorization-policies"
        case todos = "todos"
        case users = "users"
        case myUser = "my-user"
        case roles = "roles"
        case conditionValueDB = "condition-values"
        case rolesUsers = "roles_users"
    }
    
    public init() {}
}

extension APIResource {
    public static let _apiEntry: String = "api"
    public static let _all: [String] = Resource.allCases.map{$0.rawValue}
}

extension APIResource: ABACAPIResourceable {}
