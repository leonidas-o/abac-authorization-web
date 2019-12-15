import Foundation

enum APIConnection {
    static let scheme = "http"
    static let host = "localhost"
    static let port = 8080
    
    static let url = "\(APIConnection.scheme)://\(APIConnection.host):\(APIConnection.port)"
}

