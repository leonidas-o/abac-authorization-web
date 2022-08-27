import Vapor

extension ClientResponse {
    func checkHttpGet(_ auth: Auth) throws {
        let responseCode = self.status.code
        guard responseCode == 200 else {
            if responseCode == 401 {
                auth.loggedOut()
            }
            throw Abort(.internalServerError, reason: "API returned: \(responseCode)")
        }
    }
    
    func checkHttpPutPostPatch(_ auth: Auth) throws {
        let responseCode = self.status.code
        guard responseCode >= 200 && responseCode <= 299 else {
            throw Abort(.internalServerError, reason: "API returned: \(responseCode)")
        }
    }
    
    func checkHttpDeleteLogout(_ auth: Auth) throws {
        let responseCode = self.status.code
        guard responseCode == 204 else {
            throw Abort(.internalServerError, reason: "API returned: \(responseCode)")
        }
    }
    
    func checkHttpLogin(_ auth: Auth) throws {
        let responseCode = self.status.code
        guard responseCode == 200 else {
            let reason = try self.decodeErrorMessage()
            
            if responseCode == 401 {
                throw Abort(.unauthorized, reason: reason)
            }
            if responseCode == 403 {
                throw Abort(.forbidden, reason: reason)
            }
            if responseCode == 503 {
                throw Abort(.serviceUnavailable, reason: reason)
            }
            throw Abort(.internalServerError, reason: reason)
        }
    }
    private func decodeErrorMessage() throws -> String {
        let responseDecoded = try self.content.decode(ErrorData.self)
        return responseDecoded.reason
    }
}

public struct ErrorData: Codable {
    public let error: Bool
    public let reason: String
}
