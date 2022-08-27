import Vapor

struct AuthController: RouteCollection {
    
    enum Constant {
        static let accessTokenCount = 32
        static let accessTokenExpirationDefault = 60*60*24*3 //s-m-h-d
    }
    
    
    let cache: CacheRepo
    
    
    func boot(routes: RoutesBuilder) throws {
        // API
        let bearerAuthenticator = UserModelBearerAuthenticator()
        let guardMiddleware = UserModel.guardMiddleware()
        let authRoute = routes.grouped("\(APIResource.Resource.auth.rawValue)")
        // Auth Route
        // public
        authRoute.post("\(APIResource.Resource.accessData.rawValue)", use: authenticate)
        // basic authentication
        let bGroup = authRoute.grouped(UserModelBasicAuthenticator())
        bGroup.post("\(APIResource.Resource.login.rawValue)", use: loginHandler)
        // token authentication
        let gGroup = authRoute.grouped(bearerAuthenticator, guardMiddleware)
        gGroup.post("\(APIResource.Resource.logout.rawValue)", use: logoutHandler)
    }

    
    
    // MARK: - public
    
    // MARK: session based backend service only
    // (UserAuthSessionsMiddleware)
    func authenticate(_ req: Request) async throws -> User.Public {
        let data = try req.content.decode(AuthenticateData.self)
        guard let accessData = try await req.cacheRepo.get(key: data.token, as: AccessData.self) else {
            throw Abort(.unauthorized)
        }
        return accessData.userData.user.convertToUserPublic()
    }

    
    
    // MARK: - basic authentication
    
    func loginHandler(_ req: Request) async throws -> TokensResponse {
        let user = try req.auth.require(UserModel.self)
        
        async let userRoles = req.userRepo.getAllRoles(user)
        async let activeAccessToken = getActiveAccessToken(req, for: user)
                    
        user.cachedAccessToken = try await activeAccessToken?.token
        let userData = UserData(user: user.convertToUser(),
                                roles: try await userRoles.map { $0.convertToRole() })
        let accessData = try await saveNewAccessData(req, userData: userData)
        return TokensResponse(accessData: accessData.convertToAccessDataPublic())
    }
    
    
    
    // MARK: - token authentication
    
    
    func logoutHandler(_ req: Request) async throws -> HTTPStatus {
        guard let accessToken = req.headers.bearerAuthorization else {
            throw Abort(HTTPResponseStatus.internalServerError)
        }
        _ = try await cache.delete(key: accessToken.token)
        return .noContent
    }
    
    

}




// MARK: - Private helper methods
extension AuthController {
    private func getActiveAccessToken(_ req: Request, for user: UserModel) async throws -> AccessData? {
        if let cachedAccessToken = user.cachedAccessToken, !cachedAccessToken.isEmpty  {
            let array = try await req.cacheRepo.getExistingKeys(using: [cachedAccessToken], as: [AccessData].self)
            return array.first
        } else {
            return nil
        }
    }
    
    private func saveNewAccessData(_ req: Request, userData: UserData, expires expirationTime: Int = Constant.accessTokenExpirationDefault) async throws -> AccessData {
        var newAccessData = try AccessData.generate(withTokenCount: Constant.accessTokenCount, for: userData)
        let savedUser = try await req.userRepo.updateUser(fromUserData: newAccessData.userData)
        newAccessData.userData.user = savedUser.convertToUser()
        newAccessData = newAccessData.wipeOutUserPassword()
        try await req.cacheRepo.save(key: newAccessData.token, to: newAccessData)
        _ = try await req.cacheRepo.setExpiration(forKey: newAccessData.token, afterSeconds: expirationTime)
        return newAccessData
    }
    
}
