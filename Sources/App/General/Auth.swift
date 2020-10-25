import Vapor
import Foundation
import Redis

/// Backend auth session management
struct Auth {
    
    let req: Request
    
    
    func loggedOut() {
        req.session.data[TokensResponse.Constant.defaultsAccessToken] = ""
    }
    
    
    func loggedIn(with fetchedTokens: TokensResponse) {
        req.session.data[TokensResponse.Constant.defaultsAccessToken] = fetchedTokens.accessData.token
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
        return req.session.data[TokensResponse.Constant.defaultsAccessToken] ?? nil
    }
    
}
