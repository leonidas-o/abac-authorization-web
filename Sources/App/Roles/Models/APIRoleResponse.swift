import Vapor

final class APIRoleResponse: Codable {
    var type: APIResponseSourceType
    var source: [Role]
    
    init(type: APIResponseSourceType,
         source: [Role]) {
        self.type = type
        self.source = source
    }
}

extension APIRoleResponse: Content {}
