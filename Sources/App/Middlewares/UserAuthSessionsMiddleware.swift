import Vapor
import Foundation

final class UserAuthSessionsMiddleware: Middleware {
    
    let authUrl: String
    let redirectPath: String
    
    init(apiUrl: String, redirectPath: String) {
        self.authUrl = apiUrl + "/auth/authenticate"
        self.redirectPath = redirectPath
    }

    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        guard let accessToken = try request.session()[APITokensResponse.Constant.defaultsAccessToken] else {
            return redirect(request)
        }

        return try apiAccessRequest(on: request, usingURL: authUrl, accessToken: accessToken).flatMap(to: Response.self) { response in
            guard response.http.status == .ok else {
                if response.http.status != .unauthorized {
                    throw Abort(.internalServerError)
                }
                
                let newAccessToken = try response.content.syncDecode(AccessData.self)
                try request.session()[APITokensResponse.Constant.defaultsAccessToken] = newAccessToken.token
                return try self.apiAccessRequest(on: request, usingURL: self.authUrl, accessToken: newAccessToken.token).flatMap(to: Response.self) { response in
                    guard response.http.status == .ok else {
                        if response.http.status != .unauthorized {
                            throw Abort(.internalServerError)
                        }
                        return try self.logout(on: request)
                    }
                    try self.authUser(on: request, with: response)
                    return try next.respond(to: request)
                }
            }
            try self.authUser(on: request, with: response)
            return try next.respond(to: request)
        }
        
    }
    
    
    
    
    func apiAccessRequest(on request: Request, usingURL url: String, accessToken: String) throws -> Future<Response> {
        return try request.client().post(url) { request in
            try request.content.encode(APIAuthenticateData(token: accessToken))
        }.map(to: Response.self) { response in
            return response
        }
    }
    
    func logout(on request: Request) throws -> Future<Response> {
        try request.session()[APITokensResponse.Constant.defaultsAccessToken] = ""
        return self.redirect(request)
    }
    
    func authUser(on request: Request, with response: Response) throws {
        let user = try response.content.syncDecode(User.Public.self)
        try request.authenticate(user)
    }
    
    func redirect(_ request: Request) -> Future<Response> {
        let redirect = request.redirect(to: self.redirectPath)
        return request.eventLoop.newSucceededFuture(result: redirect)
    }
}
