import Vapor
import Foundation
import ABACAuthorization

final class ConditionValueDBResponse: Codable {
    var type: APIResponseSourceType
    var source: [ConditionValueDB]
    
    init(type: APIResponseSourceType, source: [ConditionValueDB]) {
        self.type = type
        self.source = source
    }
}

extension APIConditionValueDBResponse: Content {}
