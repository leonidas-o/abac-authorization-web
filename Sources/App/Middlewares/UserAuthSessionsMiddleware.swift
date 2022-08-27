import Vapor
import Foundation

final class UserAuthSessionsMiddleware: AsyncMiddleware {
    
    private let authUrl: String
    private let redirectPath: String
    
    
    init(apiUrl: String, redirectPath: String) {
        self.authUrl = apiUrl + "/\(APIResource.Resource.auth.rawValue)/\(APIResource.Resource.accessData.rawValue)"
        self.redirectPath = redirectPath
    }

    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        
        guard let accessToken = request.session.data[TokensResponse.Constant.defaultsAccessToken] else {
            return redirect(request)
        }
        
        // authenticate
        let response1 = try await apiAccessRequest(request, usingURL: authUrl, accessToken: accessToken)
        
        // if already authenticated go on
        if response1.status == .ok {
            try self.authUser(request, with: response1)
            return try await next.respond(to: request)
        }
        
        // else authenticate
        guard response1.status == .unauthorized else {
            throw Abort(.internalServerError)
        }
        let newAccessData = try response1.content.decode(AccessData.self)
        request.session.data[TokensResponse.Constant.defaultsAccessToken] = newAccessData.token
        let response2 = try await apiAccessRequest(request, usingURL: self.authUrl, accessToken: newAccessData.token)
        // if authenticated go on
        if response2.status == .ok {
            try self.authUser(request, with: response2)
            return try await next.respond(to: request)
        }
        // else logout
        guard response2.status == .unauthorized else {
            throw Abort(.internalServerError)
        }
        return self.logout(on: request)
    }
    
    
    
    
    private func apiAccessRequest(_ req: Request, usingURL url: String, accessToken: String) async throws -> ClientResponse {
        return try await req.client.post(URI(string: url)) { clientRequest in
            try clientRequest.content.encode(AuthenticateData(token: accessToken))
        }
    }
    
    private func logout(on request: Request) -> Response {
        request.session.data[TokensResponse.Constant.defaultsAccessToken] = ""
        return redirect(request)
    }
    
    private func authUser(_ req: Request, with response: ClientResponse) throws {
        let user = try response.content.decode(User.Public.self)
        req.auth.login(user)
    }
    
    private func redirect(_ req: Request) -> Response {
        return req.redirect(to: self.redirectPath)
    }
}
