import Foundation
import ABACAuthorization

public struct APIResource {
    
    public static let _apiEntry: String = "api"
    
    public static let _all: [String] = Resource.allCases.map { $0.rawValue }.sorted { $0 < $1 }
    
    public static let _allProtected: [String] = [
        APIResource.Resource.authorizationPolicy,
        APIResource.Resource.todos,
        APIResource.Resource.users,
        APIResource.Resource.myUser,
        APIResource.Resource.roles,
        APIResource.Resource.conditionValueDB,
        ].map { $0.rawValue }.sorted { $0 < $1 }

    public enum Resource: String, CaseIterable {
        case login = "login"
        case authorizationPolicy = "authorization-policies"
        case todos = "todos"
        case users = "users"
        case myUser = "my-user"
        case roles = "roles"
        case conditionValueDB = "condition-values"
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
            return APIResource._allProtected
        }
    }
}
