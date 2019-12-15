import Vapor
import Foundation

final class AuthorizationPolicyResponse: Codable {
    var type: APIResponseSourceType
    var source: [APIAuthorizationPolicy]
    
    init(type: APIResponseSourceType, source: [APIAuthorizationPolicy]) {
        self.type = type
        self.source = source
    }
}

extension AuthorizationPolicyResponse: Content {}
