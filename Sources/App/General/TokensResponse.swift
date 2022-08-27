import Vapor
import Foundation

struct TokensResponse: Codable {
    
    enum Constant {
        static let defaultsAccessToken = "API-ACCESSTOKEN"
    }

    var accessData: AccessData.Public
    
    init(accessData: AccessData.Public) {
        self.accessData = accessData
    }
}


extension TokensResponse: Content {}
