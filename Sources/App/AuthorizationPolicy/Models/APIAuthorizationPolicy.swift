import Foundation
import ABACAuthorization
import Vapor

struct APIAuthorizationPolicyResponse: Codable {
    var type: APIResponseSourceType
    var source: [APIAuthorizationPolicyWithConditions]
}


struct APIAuthorizationPolicy: Codable {
    var id: UUID?
    var roleName: String
    var actionOnResourceKey: String
    var actionOnResourceValue: Bool
}


struct APIAuthorizationPolicyWithConditions: Codable {
    var id: UUID?
    var roleName: String
    var actionOnResourceKey: String
    var actionOnResourceValue: Bool
    var conditionValues: [ConditionValueDB]
}


extension APIAuthorizationPolicy: AuthPolicyDefinition {}
extension APIAuthorizationPolicy: Content {}
extension APIAuthorizationPolicyResponse: Content {}
