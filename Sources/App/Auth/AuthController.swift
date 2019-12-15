import Vapor
import Crypto

struct AuthController: RouteCollection {
    
    private let userStore: UserPersistenceStore
    private let cache: CacheStore
    
    enum Constant {
        static let accessTokenCount = 32
        static let accessTokenExpirationDefault = 60*60*24*3 //s-m-h-d
    }

    init(userStore: UserPersistenceStore, cache: CacheStore) {
        self.userStore = userStore
        self.cache = cache
    }
    
    
    
    func boot(router: Router) throws {
        let authGroup = router.grouped("auth")
        
        authGroup.post(APIAuthenticateData.self, at: "authenticate", use: authenticate)
        
        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = authGroup.grouped(basicAuthMiddleware)
        basicAuthGroup.post("login", use: loginHandler)
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = authGroup.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.post("logout", use: logoutHandler)
    }

    
    
    
    func loginHandler(_ req: Request) throws -> Future<APITokensResponse> {
        let user = try req.requireAuthenticated(User.self)
        
        return userStore.getAllRoles(from: user).flatMap{ userRoles in
            let userData = UserData(user: user, roles: userRoles.source)
            return try self.generateNewAccessToken(with: userData).map{ accessToken in
                return APITokensResponse(accessData: accessToken)
            }
        }
        
    }
        
    func logoutHandler(_ req: Request) throws -> Future<HTTPStatus> {
        guard let accessToken = req.http.headers.bearerAuthorization else {
            throw Abort(HTTPResponseStatus.internalServerError)
        }
        return cache.delete(key: accessToken.token).transform(to: .noContent)
    }
    
    
    // MARK: Only for session based backend services (e.g. UserAuthSessionsMiddleware)
    func authenticate(_ req: Request, data: APIAuthenticateData) throws -> Future<User.Public> {
        return cache.get(key: data.token, as: AccessData.self).map(to: User.Public.self) { token in
            guard let token = token else {
                throw Abort(.unauthorized)
            }
            return token.userData.user.convertToPublic()
        }
    }

}




// MARK: - Private helper methods
extension AuthController {
    
    private func generateNewAccessToken(with userData: UserData, expires expirationTime: Int = Constant.accessTokenExpirationDefault) throws -> Future<AccessData> {
        let newToken = try AccessData.generate(withTokenCount: Constant.accessTokenCount, for: userData)
        return cache.save(key: newToken.token, to: newToken).then{  _ -> Future<Int> in
            return self.cache.setExpiration(forKey: newToken.token, afterSeconds: expirationTime)
        }.transform(to: newToken)
    }
    
}
