import Foundation


struct APIResource {
    
    static let _apiEntry: String = "api"
    
    
    static let _all: [String] = Resource.allCases.map { $0.rawValue }.sorted { $0 < $1 }
    
    
    static let _allProtected: [String] = [
        APIResource.Resource.auth,
        APIResource.Resource.todos,
        APIResource.Resource.users,
        APIResource.Resource.myUser,
        APIResource.Resource.roles,
        // ABACAuthorization
        APIResource.Resource.abacAuthPolicies,
        APIResource.Resource.abacConditions,
        
    ].map { $0.rawValue }.sorted { $0 < $1 }

    
    enum Resource: String, CaseIterable {
        case login = "login"
        case logout = "logout"
        case auth = "auth"
        case bulk = "bulk"
        case accessData = "access-data"
        // ABACAuthorization
        case abacAuthPolicies = "abac-auth-policies"
        case abacAuthPoliciesService = "abac-auth-policies-service"
        case abacConditions = "abac-conditions"
        // Others
        case todos = "todos"
        case users = "users"
        case myUser = "my-user"
        case roles = "roles"
    }
    
}
