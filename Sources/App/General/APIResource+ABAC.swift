import Foundation
import ABACAuthorization

public struct APIResource {
    
    public static let _apiEntry: String = "api"

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




extension APIResource: ABACAPIResourceable {
    public var apiEntry: String {
        get {
            return APIResource._apiEntry
        }
    }
    public var all: [String] {
        get {
            return Resource.allCases.map{ $0.rawValue }
        }
    }
}
