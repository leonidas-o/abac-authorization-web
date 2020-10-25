import Vapor
import Fluent
import Redis
import ABACAuthorization


/// An ephermal authentication token that identifies a registered user.
struct AccessData: Codable {
    /// UserToken's unique identifier.
    var id: UUID?
    /// Unique token string.
    var token: String
    /// Reference to user that owns this token.
    var userId: UUID
    
    var userData: UserData
    
    /// Creates a new former `UserToken` now called AccessData.
    init(token: String, userId: UUID, userData: UserData) {
        self.token = token
        self.userId = userId
        self.userData = userData
    }
    
    
    struct Public: Codable {
        var id: UUID?
        var token: String
        var userId: UUID // TODO: Remove User ID as it is already in userData
        var userData: UserData.Public // TODO: Keep it in sync with data from db
        
        init(token: String, userId: UUID, userData: UserData.Public) {
            self.token = token
            self.userId = userId
            self.userData = userData
        }
    }
}



// MARK: - Conversion

extension AccessData {
    func convertToAccessDataPublic() -> AccessData.Public {
        return AccessData.Public(token: token,
                                 userId: userId,
                                 userData: userData.convertToUserDataPublic())
    }
}



// MARK: - Conformance

/// Allows `UserToken` to be encoded to and decoded from HTTP messages.
extension AccessData: Content {}
extension AccessData.Public: Content {}



// MARK: - Helper methods

extension AccessData {
    static func generate(withTokenCount count: Int, for userData: UserData) throws -> AccessData {
        
        var userData = userData
        let random = [UInt8].random(count: count).base64
        userData.user.cachedAccessToken = random
        guard let userId = userData.user.id else {
            throw ModelError.idRequired
        }
        return AccessData(token: random, userId: userId, userData: userData)
    }
}

extension AccessData {
    func wipeOutUserPassword() -> AccessData {
        var mod = self
        mod.userData.user.password = ""
        return mod
    }
}



// MARK: - ABAC Authorization

extension AccessData: ABACAccessData {}
