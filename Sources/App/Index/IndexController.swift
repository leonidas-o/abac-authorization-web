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
    
    
    
    func overviewHandler(_ req: Request) async throws -> View {
        let user = try req.auth.require(User.Public.self)
        let context: OverviewContext
        context = OverviewContext(user: user,
                                  error: req.query[String.self, at: "error"])
        return try await req.view.render("index", context)
    }
    
    func logoutTmpHandler(_ req: Request) async throws -> Response {
        let auth = Auth(req: req)
        guard let token = auth.accessToken else {
            throw Abort(HTTPResponseStatus.notFound, reason: "AccessToken not found")
        }
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource.Resource.auth.rawValue)/\(APIResource.Resource.logout.rawValue)")
        let response = try await req.client.post(uri) { clientReq in
            clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
        }
        do {
            try response.checkHttpDeleteLogout(auth)
            auth.loggedOut()
            return req.redirect(to: "/")
        } catch {
            let errorMessage = error.getMessage()
            return req.redirect(to: "/?error=\(errorMessage)")
        }
    }
    
    
    
    func loginTmpHandler(_ req: Request) async throws -> View {
        let context = LoginContext(error: req.query[String.self, at: "error"])
        return try await req.view.render("login", context)
    }
    
    func loginTmpPostHandler(_ req: Request) async throws -> Response {
        let loginData = try req.content.decode(LoginData.self)
        
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource.Resource.auth.rawValue)/\(APIResource.Resource.login.rawValue)")
        let response = try await req.client.post(uri) { clientReq in
            clientReq.headers.basicAuthorization = BasicAuthorization(username: loginData.username, password: loginData.password)
        }
        do {
            try response.checkHttpLogin(auth)
            let responseDecoded = try response.content.decode(TokensResponse.self)
            Auth(req: req).loggedIn(with: responseDecoded)
            return req.redirect(to: "/")
        } catch {
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


