import Foundation
import Vapor

struct IndexController: RouteCollection {
    
    func boot(router: Router) throws {
        router.get("login", use: loginTmpHandler)
        router.post(APILoginData.self, at: "login", use: loginTmpPostHandler)
        
        let authGroup = router.grouped(UserAuthSessionsMiddleware(apiUrl: "http://localhost:8080", redirectPath: "/login"))
        authGroup.post("logout", use: logoutTmpHandler)
        authGroup.get(use: overviewHandler)
    }
    
    
    
    func overviewHandler(_ req: Request) throws -> Future<View> {
        let user = try req.requireAuthenticated(User.Public.self)
        let context: OverviewContext
        context = OverviewContext(user: user,
                                  error: req.query[String.self, at: "error"])
        return try req.view().render("index", context)
    }
    
    func logoutTmpHandler(_ req: Request) throws -> Future<Response> {
        let auth = Auth(req: req)
        guard let token = auth.getAccessToken() else {
            throw Abort(HTTPResponseStatus.notFound, reason: "AccessToken not found")
        }
        let logoutRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/auth/logout")
        return logoutRequest.futureLogout(token: token, on: req)
            .map(to: Response.self) { apiResponse in
                auth.loggedOut()
                return req.redirect(to: "/")
            }.catchMap { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/?error=\(errorMessage)")
        }
    }
    
    func loginTmpHandler(_ req: Request) throws -> Future<View> {
        let context: LoginContext
        context = LoginContext(error: req.query[String.self, at: "error"])
        return try req.view().render("login", context)
    }
    
    func loginTmpPostHandler(_ req: Request, loginData: APILoginData) throws -> Future<Response> {
        let loginRequest = ResourceRequest<NoRequestType, APITokensResponse>(resourcePath: "/auth/login")
        return loginRequest.futureLogin(username: loginData.username, password: loginData.password, on: req)
            .map { apiResponse in
                Auth(req: req).loggedIn(with: apiResponse)
                return req.redirect(to: "/")
            }.catchMap { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/login?error=\(errorMessage)")
        }
    }
    
}




// MARK: - Frontend contexts

struct OverviewContext: Encodable {
    let title = "Overview"
    let user: User.Public
    let error: String?
}

struct LoginContext: Encodable {
    let title = "Login"
    let error: String?
}


