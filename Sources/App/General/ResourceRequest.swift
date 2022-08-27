import Foundation

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
