import Vapor
import Foundation


final class UserAuthSessionsMiddleware: Middleware {
    
    private let authUrl: String
    private let redirectPath: String
    
    
    init(apiUrl: String, redirectPath: String) {
        self.authUrl = apiUrl + "/\(APIResource.Resource.auth.rawValue)/\(APIResource.Resource.accessData.rawValue)"
        self.redirectPath = redirectPath
    }

    
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        
        guard let accessToken = request.session.data[TokensResponse.Constant.defaultsAccessToken] else {
            return redirect(request)
        }
        
        // authenticate
        return apiAccessRequest(request, usingURL: authUrl, accessToken: accessToken).flatMap { response in
            // if already authenticated go on
            if response.status == .ok {
                do {
                    try self.authUser(request, with: response)
                } catch {
                    return request.eventLoop.makeFailedFuture(error)
                }
                return next.respond(to: request)
            }
            
            // else authenticate
            guard response.status == .unauthorized else {
                return request.eventLoop.makeFailedFuture(Abort(.internalServerError))
            }
            let newAccessData: AccessData
            do {
                newAccessData = try response.content.decode(AccessData.self)
            }
            catch {
                return request.eventLoop.makeFailedFuture(error)
            }
            request.session.data[TokensResponse.Constant.defaultsAccessToken] = newAccessData.token
            
            return self.apiAccessRequest(request, usingURL: self.authUrl, accessToken: newAccessData.token).flatMap { response in
                // if authenticated go on
                if response.status == .ok {
                    do {
                        try self.authUser(request, with: response)
                    } catch {
                        return request.eventLoop.makeFailedFuture(error)
                    }
                    return next.respond(to: request)
                }
                // else logout
                guard response.status == .unauthorized else {
                    return request.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
                return self.logout(on: request)
            }
        }
        
    }
    
    
    
    
    private func apiAccessRequest(_ req: Request, usingURL url: String, accessToken: String) -> EventLoopFuture<ClientResponse> {
        return req.client.post(URI(string: url)) { clientRequest in
            try clientRequest.content.encode(AuthenticateData(token: accessToken))
        }
    }
    
    private func logout(on request: Request) -> EventLoopFuture<Response> {
        request.session.data[TokensResponse.Constant.defaultsAccessToken] = ""
        return self.redirect(request)
    }
    
    private func authUser(_ req: Request, with response: ClientResponse) throws {
        let user = try response.content.decode(User.Public.self)
        req.auth.login(user)
    }
    
    private func redirect(_ req: Request) -> EventLoopFuture<Response> {
        let redirect = req.redirect(to: self.redirectPath)
        return req.eventLoop.makeSucceededFuture(redirect)
    }
}
