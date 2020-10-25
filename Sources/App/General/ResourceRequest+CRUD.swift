import Vapor
import Foundation

extension ResourceRequest {
    
    struct URLRequestWithBodyParams {
        let httpMethod: String
        let resource: RequestType
        let req: Request
        let token: String
        let completion: (GetResourceRequest<ResponseType>) -> Void
    }
    
    struct URLRequestWithoutBodyParams {
        let httpMethod: String
        let req: Request
        let token: String
        let completion: (GetResourceRequestStatus<Int>) -> Void
    }
    
    
    
    func logout(token: String, completion: @escaping (GetResourceRequest<Int>) -> Void) {
        
        var logoutRequest = URLRequest(url: resourceURL)
        logoutRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        logoutRequest.httpMethod = "POST"
                
        let session = URLSession(configuration: .default)
        let dataTask = session.dataTask(with: logoutRequest) { _, response, error in
            if let error = error {
                completion(.failure(ResourceError.network(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ResourceError.corrupt("Response/data not readable")))
                return
            }
            if httpResponse.statusCode != 204 {
                completion(.failure(ResourceError.httpStatus(httpResponse.statusCode)))
                return
            }
            completion(.success(httpResponse.statusCode))
        }
        dataTask.resume()
    }
    
    
    
    func create(_ req: Request, resourceToSave: RequestType, completion: @escaping (GetResourceRequest<ResponseType>) -> Void) {
        guard let token = Auth(req: req).getAccessToken() else {
            fatalError("ResourceRequest: Could not retrieve AccessToken")
        }

        let params = URLRequestWithBodyParams(httpMethod: "POST",
                                              resource: resourceToSave,
                                              req: req,
                                              token: token,
                                              completion: completion)
        let urlRequest = self.prepareURLRequestWithBody(params)
        if let urlRequest = urlRequest {
            self.sendRequestWithDataResponse(urlRequest, completion: completion)
        }
    }
    func createWithoutDataResponse(_ req: Request, resourceToSave: RequestType, completion: @escaping (GetResourceRequestStatus<Int>) -> Void) {
        guard let token = Auth(req: req).getAccessToken() else {
            fatalError("ResourceRequest: Could not retrieve AccessToken")
        }

        let params = URLRequestWithoutBodyParams(httpMethod: "POST",
                                              req: req,
                                              token: token,
                                              completion: completion)
        let urlRequest = self.prepareURLRequestWithoutBody(params)
        if let urlRequest = urlRequest {
            let session = URLSession(configuration: .default)
            let dataTask = session.dataTask(with: urlRequest) { _, response, error in
                if let error = error {
                    completion(.failure(ResourceError.network(error)))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(ResourceError.corrupt("Response/data not readable")))
                    return
                }
                if httpResponse.statusCode < 200 || httpResponse.statusCode > 299 {
                    completion(.failure(ResourceError.httpStatus(httpResponse.statusCode)))
                    return
                }
                completion(.success(httpResponse.statusCode))
            }
            dataTask.resume()
        }
    }
    
    
    func getAll(_ req: Request, completion: @escaping (GetResourceRequest<ResponseType>) -> Void) {
        let auth = Auth(req: req)
        guard let token = auth.getAccessToken() else {
            fatalError("ResourceRequest: Could not retrieve AccessToken")
        }
        
        
        var tokenRequest = URLRequest(url: self.resourceURL)
        tokenRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default)
        let dataTask = session.dataTask(with: tokenRequest) { data, response, error in
            
            if let error = error {
                completion(.failure(ResourceError.network(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(ResourceError.corrupt("Response/data not readable")))
                return
            }
            if httpResponse.statusCode != 200 {
                if httpResponse.statusCode == 401 {
                    auth.loggedOut()
                }
                completion(.failure(ResourceError.httpStatus(httpResponse.statusCode)))
                return
            }
            self.decode(data, completion: completion)
        }
        dataTask.resume()
    }
    
    
    
    func update(_ req: Request, resourceToUpdate: RequestType, completion: @escaping (GetResourceRequest<ResponseType>) -> Void) {
        guard let token = Auth(req: req).getAccessToken() else {
            fatalError("RsourceRequest: Could not retrieve AccessToken")
        }
        let params = URLRequestWithBodyParams(httpMethod: "PUT",
                                              resource: resourceToUpdate,
                                              req: req,
                                              token: token,
                                              completion: completion)
        let urlRequest = self.prepareURLRequestWithBody(params)
        if let urlRequest = urlRequest {
            self.sendRequestWithDataResponse(urlRequest, completion: completion)
        }
    }
    
    
    
    func delete(_ req: Request, completion: @escaping (GetResourceRequestStatus<Int>) -> Void) {
        guard let token = Auth(req: req).getAccessToken() else {
            fatalError("RsourceRequest: Could not retrieve AccessToken")
        }
        let params = URLRequestWithoutBodyParams(httpMethod: "DELETE",
                                                 req: req,
                                                 token: token,
                                                 completion: completion)
        let urlRequest = self.prepareURLRequestWithoutBody(params)
        if let urlRequest = urlRequest {
            //self.sendRequest(urlRequest, completion: completion)
            let session = URLSession(configuration: .default)
            let dataTask = session.dataTask(with: urlRequest) { _, response, error in
                if let error = error {
                    completion(.failure(ResourceError.network(error)))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(ResourceError.corrupt("Response/data not readable")))
                    return
                }
                if httpResponse.statusCode != 204 {
                    completion(.failure(ResourceError.httpStatus(httpResponse.statusCode)))
                    return
                }
                completion(.success(httpResponse.statusCode))
            }
            dataTask.resume()
        }
    }
    
}




// MARK: - Private helper methods
extension ResourceRequest {
    
    private func prepareURLRequestWithBody(_ params: URLRequestWithBodyParams) -> URLRequest? {
        if params.token.isEmpty {
            params.completion(.failure(.unauthorized("Unauthorized")))
            return nil
        }
        var urlRequest = URLRequest(url: self.resourceURL)
        urlRequest.httpMethod = params.httpMethod
        urlRequest.addValue("Bearer \(params.token)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            urlRequest.httpBody = try JSONEncoder().encode(params.resource)
        } catch {
            params.completion(.failure(ResourceError.decoding(error)))
        }
        return urlRequest
    }
    
    private func prepareURLRequestWithoutBody(_ params: URLRequestWithoutBodyParams) -> URLRequest? {
        if params.token.isEmpty {
            params.completion(.failure(.unauthorized("Unauthorized")))
            return nil
        }
        var urlRequest = URLRequest(url: resourceURL)
        urlRequest.addValue("Bearer \(params.token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpMethod = params.httpMethod
        return urlRequest
    }
    
    private func sendRequestWithDataResponse(_ urlRequest: URLRequest, completion: @escaping (GetResourceRequest<ResponseType>) -> Void) {
        let session = URLSession(configuration: .default)
        let dataTask = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(ResourceError.network(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(ResourceError.corrupt("Response/data not readable")))
                return
            }
            if httpResponse.statusCode != 200 {
                completion(.failure(ResourceError.httpStatus(httpResponse.statusCode)))
                return
            }
            self.decode(data, completion: completion)
        }
        dataTask.resume()
    }
        
}
