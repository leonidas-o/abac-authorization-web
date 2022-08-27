import Foundation
import Vapor

protocol RoleDefinition {
    var id: Int? { get set }
    var name: String { get set }
}


struct Role: Codable {
    var id: Int?
    var name: String
    
    init(id: Int? = nil, name: String) {
        self.id = id
        self.name = name
    }
}


extension Role: RoleDefinition, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: Role, rhs: Role) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}



// MARK: - Vapor conformances

extension Role: Content {}
