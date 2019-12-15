import Foundation

extension Error {
    func getMessage() -> String {
        let errorMessage: String
        if let resourceError = self as? ResourceError {
            switch resourceError {
            case .httpStatus(let statusCode):
                errorMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
            case .corrupt(let message):
                errorMessage = message
            case .decoding(let error):
                errorMessage = error.localizedDescription
            case .encoding(let error):
                errorMessage = error.localizedDescription
            case .network(let error):
                errorMessage = error.localizedDescription
            case .unauthorized(let message):
                errorMessage = message
            case .forbidden(let message):
                errorMessage = message
            case .internalServerError(let message):
                errorMessage = message
            }
        } else {
            errorMessage = self.localizedDescription
        }
        return errorMessage
    }
}
