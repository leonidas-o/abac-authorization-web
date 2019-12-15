import Vapor
import Authentication
import Foundation
import ABACAuthorization

extension User.Public: Authenticatable {}
extension User.Public: Content {}

extension APIAuthenticateData: Content {}

extension Role: Content {}

extension APITokensResponse: Content {}
