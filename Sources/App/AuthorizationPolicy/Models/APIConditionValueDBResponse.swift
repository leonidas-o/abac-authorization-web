import Foundation
import ABACAuthorization

struct APIConditionValueDBResponse: Codable {
    var type: APIResponseSourceType
    var source: [ConditionValueDB]
}
