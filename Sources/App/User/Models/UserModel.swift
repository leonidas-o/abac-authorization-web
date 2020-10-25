import Vapor
import Fluent
import ABACAuthorization


protocol UserDefinition {
    var id: UUID? { get set }
    var name: String { get set }
    var email: String { get set }
    var password: String { get set }
    var cachedAccessToken: String? { get set }
    
    func convertToUserPublic() -> User.Public
}


final class UserModel: Model {
    
    static let schema = "user"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @Field(key: "email") var email: String
    @Field(key: "password") var password: String
    @OptionalField(key: "cached_access_token") var cachedAccessToken: String?
    
    // Siblings - values in pivot table
    @Siblings(through: UserRolePivot.self, from: \.$user, to: \.$role) public var roles: [RoleModel]
    
    
    init() {}
    
    init(id: UUID? = nil,
         name: String,
         email: String,
         password: String,
         cachedAccessToken: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.password = password
        self.cachedAccessToken = cachedAccessToken
    }
    
}



// MARK: - General conformance

/// Allows `UserModel` to be encoded to and decoded from HTTP messages.
extension UserModel: Content {}



// MARK: - DTO conversion

extension UserModel: UserDefinition {
    func convertToUserPublic() -> User.Public {
        return User.Public(id: id, name: name, email: email)
    }
}

extension UserModel {
    func convertToUser() -> User {
        return User(id: id,
                    name: name,
                    email: email,
                    password: password,
                    cachedAccessToken: cachedAccessToken)
    }
}


extension User {
    func convertToUserModel() -> UserModel {
        return UserModel(id: id,
                         name: name,
                         email: email,
                         password: password,
                         cachedAccessToken: cachedAccessToken)
    }
}



// MARK: - Authentication

extension UserModel: Authenticatable {}

// Basic Authentication
// Note: Used the manual approach, instead Fluents 'ModelAuthenticatable'
extension UserModel {
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

struct UserModelBasicAuthenticator: BasicAuthenticator {
    typealias User = App.UserModel

    func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
        UserModel.query(on: request.db)
            .filter(\.$email == basic.username)
            .first()
            .flatMapThrowing {
            guard let user = $0 else {
                // TODO: Test on invalid auth what the response code is
                return
            }
            guard try user.verify(password: basic.password) else {
                return
            }
            request.auth.login(user)
        }
   }
}

// Token Authentication
// Note: Used the manual approach, instead Fluents 'ModelTokenAuthenticatable'
struct UserModelBearerAuthenticator: BearerAuthenticator {

    struct AccessDataKey: StorageKey {
        typealias Value = AccessData
    }
    
    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
        return request.cacheRepo.get(key: bearer.token, as: AccessData.self).flatMap { accessData in
            guard let accessData = accessData else {
                return request.eventLoop.makeSucceededFuture(())
            }
            let user = accessData.userData.user.convertToUserModel()
            request.auth.login(user)
            request.storage.set(AccessDataKey.self, to: accessData)
            return request.eventLoop.makeSucceededFuture(())
        }
    }
}



// MARK: - Migration

/// Allows `User` to be used as a Fluent migration.
struct UserModelMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user")
        .id()
        .field("name", .string, .required)
        .field("email", .string, .required)
        .unique(on: "email")
        .field("password", .string, .required)
        .field("cached_access_token", .string)
        .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user")
        .delete()
    }
}



// MARK: - ABACAuthorization

extension UserModel: ABACUser {}
