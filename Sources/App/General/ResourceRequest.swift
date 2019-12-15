import Foundation

enum GetResourceRequest<ResponseType> {
    case success(ResponseType)
    case failure(ResourceError)
}

enum GetResourceRequestStatus<Int> {
    case success(Int)
    case failure(ResourceError)
}

enum ResourceError: Error {
    case network(Error)
    case decoding(Error)
    case encoding(Error)
    case httpStatus(Int)
    case corrupt(String)
    case unauthorized(String)
    case forbidden(String)
    case internalServerError(String)
}


struct ResourceRequest<RequestType: Codable, ResponseType: Codable> {
    
    var baseURLComponent = URLComponents()
    var resourceURL: URL
    let dateFormatter = DateFormatter.IsoDateFormatter
    
    init(baseUrlComponent: URLComponents? = nil, resourcePath: String, queryStrings: [String:String]? = nil) {
        if let urlComponent = baseUrlComponent {
            self.baseURLComponent = urlComponent
        } else {
            baseURLComponent.scheme = APIConnection.scheme
            baseURLComponent.host = APIConnection.host
            baseURLComponent.port = APIConnection.port
            baseURLComponent.path = resourcePath
        }
        if let queryStringsParams = queryStrings {
            baseURLComponent.setQueryItems(with: queryStringsParams)
        }
        guard let resourceURL = baseURLComponent.url else {
            fatalError()
        }
        self.resourceURL = resourceURL
    }
    
    
    
    func login(username: String, password: String, completion: @escaping (GetResourceRequest<ResponseType>) -> Void) {
        
        guard let loginString = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() else {
            fatalError()
        }
        var loginRequest = URLRequest(url: resourceURL)
        loginRequest.addValue("Basic \(loginString)", forHTTPHeaderField: "Authorization")
        loginRequest.httpMethod = "POST"
        
        let session = URLSession(configuration: .default)
        let dataTask = session.dataTask(with: loginRequest) { data, response, _ in
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(ResourceError.corrupt("Response/data not readable")))
                return
            }
            if httpResponse.statusCode != 200 {
                if httpResponse.statusCode == 401 {
                    completion(.failure(ResourceError.unauthorized("Unauthorized: Either your username or password was invalid")))
                    return
                }
                if httpResponse.statusCode == 403 {
                    completion(.failure(ResourceError.forbidden("Forbidden: No new logins possible")))
                    return
                }
                completion(.failure(ResourceError.internalServerError("Internal Server Error")))
                return
            }
            self.decode(data, completion: completion)
        }
        dataTask.resume()
    }
    
    
    
    func decode(_ data: Data, completion: (GetResourceRequest<ResponseType>) -> Void) {
        do {
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .formatted(self.dateFormatter)
            let resource = try jsonDecoder.decode(ResponseType.self, from: data)
            completion(.success(resource))
        } catch {
            completion(.failure(ResourceError.decoding(error)))
        }
    }
}


extension URLComponents {
    mutating func setQueryItems(with parameters: [String:String]) {
        self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}

struct NoRequestType: Codable {}
struct StatusCodeResponseType: Codable {}
