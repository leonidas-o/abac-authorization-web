import Foundation

enum ModelError: Error, LocalizedError, CustomStringConvertible {
    case idRequired
    case migrationFailed(reason: String)
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case conversionFailed(reason: String)

    var description: String {
        switch self {
        case .idRequired:
            return "ID required"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .encodingFailed(reason: let reason):
            return "Encoding failed: \(reason)"
        case .decodingFailed(reason: let reason):
            return "Decoding failed: \(reason)"
        case .conversionFailed(reason: let reason):
            return "Model conversion failed: \(reason)"
        }
    }

    var errorDescription: String? {
        return self.description
    }
}
