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
    func authenticate(_ req: Request) throws -> EventLoopFuture<User.Public> {
        let data = try req.content.decode(AuthenticateData.self)
        return req.cacheRepo.get(key: data.token, as: AccessData.self).unwrap(or: Abort(.unauthorized)).flatMapThrowing { accessData in
            return accessData.userData.user.convertToUserPublic()
        }
    }

    
    
    // MARK: - basic authentication
    
    func loginHandler(_ req: Request) throws -> EventLoopFuture<TokensResponse> {
        let user = try req.auth.require(UserModel.self)
        
        return req.userRepo.getAllRoles(user)
            .and(getActiveAccessToken(req, for: user)).flatMap { userRoles, activeAccessToken in
            
            user.cachedAccessToken = activeAccessToken?.token
            let userData = UserData(user: user.convertToUser(),
                                    roles: userRoles.map { $0.convertToRole() })
            return saveNewAccessData(req, userData: userData).map { accessData in
                return TokensResponse(accessData: accessData.convertToAccessDataPublic())
            }
        }
        
    }
    
    
    
    // MARK: - token authentication
    
    
    func logoutHandler(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let accessToken = req.headers.bearerAuthorization else {
            throw Abort(HTTPResponseStatus.internalServerError)
        }
        return cache.delete(key: accessToken.token).transform(to: .noContent)
    }
    
    

}




// MARK: - Private helper methods
extension AuthController {
    private func getActiveAccessToken(_ req: Request, for user: UserModel) -> EventLoopFuture<AccessData?> {
        if let cachedAccessToken = user.cachedAccessToken, !cachedAccessToken.isEmpty  {
            return req.cacheRepo.getExistingKeys(using: [cachedAccessToken], as: [AccessData].self).map { array in
                return array.first
            }
        } else {
            return req.eventLoop.makeSucceededFuture(nil)
        }
    }
    
    private func saveNewAccessData(_ req: Request, userData: UserData, expires expirationTime: Int = Constant.accessTokenExpirationDefault) -> EventLoopFuture<AccessData> {
        var newAccessData: AccessData
        do {
            newAccessData = try AccessData.generate(withTokenCount: Constant.accessTokenCount, for: userData)
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
        return req.userRepo.updateUser(fromUserData: newAccessData.userData).flatMap { savedUser in
            newAccessData.userData.user = savedUser.convertToUser()
            newAccessData = newAccessData.wipeOutUserPassword()
            return req.cacheRepo.save(key: newAccessData.token, to: newAccessData).flatMap {
                return req.cacheRepo.setExpiration(forKey: newAccessData.token, afterSeconds: expirationTime)
            }.transform(to: newAccessData)
        }
    }
    
}
