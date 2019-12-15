import Vapor
import Foundation

final class APIUserResponse: Codable {
    
    var type: APIResponseSourceType
    var source: [APIUserData]
    
    init(type: APIResponseSourceType, source: [APIUserData]) {
        self.type = type
        self.source = source
    }
}

extension APIUserResponse: Content {}
