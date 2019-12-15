import Foundation
import Vapor

public struct APIAuthenticateData: Codable {
    public let id: UUID?
    public let token: String
    
    public init(id: UUID? = nil, token: String) {
        self.id = id
        self.token = token
    }
}
