import Vapor
import Foundation
import Redis

final class Auth {
    
    private let req: Request
    
    init(req: Request) {
        self.req = req
    }
    
    
    
    func loggedOut() {
        do {
            try req.session()[APITokensResponse.Constant.defaultsAccessToken] = ""
        } catch {
            fatalError("Cache: Could not remove tokens")
        }
    }
    
    func loggedIn(with fetchedTokens: APITokensResponse) {
        do {
            try req.session()[APITokensResponse.Constant.defaultsAccessToken] = fetchedTokens.accessData.token
        } catch {
            fatalError("Cache: Could not set tokens")
        }
    }
    
    
    func isAuthenticated() -> Bool {
        guard let token = getAccessToken() else {
            return false
        }
        if token.isEmpty {
            return false
        } else {
            return true
        }
    }
    
    func getAccessToken() -> String? {
        do {
            return try req.session()[APITokensResponse.Constant.defaultsAccessToken] ?? nil
        } catch {
            return nil
        }
    }
    
}


public struct APITokensResponse: Codable {
    
    public enum Constant {
        public static let defaultsAccessToken = "API-ACCESSTOKEN"
    }

    var accessData: AccessData
    
    init(accessData: AccessData) {
        self.accessData = accessData
    }
}
