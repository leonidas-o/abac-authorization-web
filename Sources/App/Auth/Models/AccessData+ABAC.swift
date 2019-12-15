import Authentication
import FluentPostgreSQL
import Vapor
import Redis
import ABACAuthorization

/// An ephermal authentication token that identifies a registered user.
final class AccessData: Codable {
        
    /// UserToken's unique identifier.
    var id: UUID?
    
    /// Unique token string.
    var token: String
    
    /// Reference to user that owns this token.
    var userID: User.ID
        
    var userData: UserData
    
    /// Creates a new former `UserToken` now just called AccessData.
    init(id: UUID? = nil, token: String, userID: User.ID, userData: UserData) {
        self.id = id
        self.token = token
        self.userID = userID
        self.userData = userData
    }
}

extension AccessData {
    static func generate(withTokenCount count: Int, for userData: UserData) throws -> AccessData {
        let random = try CryptoRandom().generateData(count: count)
        return try .init(token: random.base64EncodedString(), userID: userData.user.requireID(), userData: userData)
    }
}

/// Allows this model to be used as a TokenAuthenticatable's token.
extension AccessData: Token {
    
    /// See `Token`.
    typealias UserType = User
    
    /// See `Token`.
    static var tokenKey: WritableKeyPath<AccessData, String> {
        return \.token
    }
    
    /// See `Token`.
    static var userIDKey: WritableKeyPath<AccessData, User.ID> {
        return \.userID
    }
    
    typealias UserIDType = User.ID
}

extension AccessData: BearerAuthenticatable {
    static func authenticate(using bearer: BearerAuthorization, on connection: DatabaseConnectable) -> EventLoopFuture<AccessData?> {
        let redis = connection.databaseConnection(to: .redis)
        return redis.flatMap { redis -> Future<AccessData?> in
            return redis.jsonGet(bearer.token, as: AccessData.self)
        }
    }
}


/// Allows `UserToken` to be encoded to and decoded from HTTP messages.
extension AccessData: Content { }

/// Allows `UserToken` to be used as a dynamic parameter in route definitions.
extension AccessData: Parameter {
    typealias ResolvedParameter = Future<AccessData>
    
    static func resolveParameter(_ parameter: String, on container: Container) throws -> EventLoopFuture<AccessData> {
        return container.withPooledConnection(to: .redis) { redis in
            return redis.jsonGet(parameter, as: AccessData.self)
            }.map(to: AccessData.self) { token in
                guard let token = token else {
                    throw Abort(HTTPResponseStatus.badRequest)
                }
                return token
        }
    }
}

extension AccessData: ABACAccessData {}
