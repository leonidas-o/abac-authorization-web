import Foundation
import Vapor

struct IndexController: RouteCollection {
    
    
    func boot(routes: RoutesBuilder) throws {
        // Frontend
        // Public
        routes.get("login", use: loginTmpHandler)
        routes.post("login", use: loginTmpPostHandler)
        // Authenticated
        let authGroup = routes.grouped(UserAuthSessionsMiddleware(apiUrl: "http://localhost:8080", redirectPath: "/login"))
        authGroup.post("logout", use: logoutTmpHandler)
        authGroup.get(use: overviewHandler)
    }
    
    
    
    func overviewHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try req.auth.require(User.Public.self)
        let context: OverviewContext
        context = OverviewContext(user: user,
                                  error: req.query[String.self, at: "error"])
        return req.view.render("index", context)
    }
    
    func logoutTmpHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let auth = Auth(req: req)
        guard let token = auth.getAccessToken() else {
            throw Abort(HTTPResponseStatus.notFound, reason: "AccessToken not found")
        }
        let logoutRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/\(APIResource.Resource.auth.rawValue)/\(APIResource.Resource.logout.rawValue)")
        return logoutRequest.futureLogout(req, token: token).map { apiResponse in
                auth.loggedOut()
                return req.redirect(to: "/")
        }.flatMapErrorThrowing { error in
                let errorMessage = error.getMessage()
            return req.redirect(to: "/?error=\(errorMessage)")
        }
    }
    
    
    
    func loginTmpHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let context = LoginContext(error: req.query[String.self, at: "error"])
        return req.view.render("login", context)
    }
    
    func loginTmpPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        let loginData = try req.content.decode(LoginData.self)
        let loginRequest = ResourceRequest<NoRequestType, TokensResponse>(resourcePath: "/\(APIResource.Resource.auth.rawValue)/\(APIResource.Resource.login.rawValue)")
        return loginRequest.futureLogin(req, username: loginData.username, password: loginData.password)
            .map { apiResponse in
                Auth(req: req).loggedIn(with: apiResponse)
                return req.redirect(to: "/")
            }.flatMapErrorThrowing { error in
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


