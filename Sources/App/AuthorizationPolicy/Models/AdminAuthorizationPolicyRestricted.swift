import Vapor
import FluentPostgreSQL
import Foundation
import ABACAuthorization


struct AdminAuthorizationPolicyRestricted: Migration {
    typealias Database = PostgreSQLDatabase
    
    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        
        return Role.query(on: conn).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
            let readAuthPolicyActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.authorizationPolicy.rawValue)"
            let readAuthPolicy = AuthorizationPolicy(
                roleName: role.name,
                actionOnResource: readAuthPolicyActionOnResource,
                actionOnResourceValue: true)
            
            let createAuthPolicyActionOnResource = "\(ABACAPIAction.create)\(APIResource.Resource.authorizationPolicy.rawValue)"
            let writeAuthPolicy = AuthorizationPolicy(
                roleName: role.name,
                actionOnResource: createAuthPolicyActionOnResource,
                actionOnResourceValue: true)
            
            let readRoleActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.roles.rawValue)"
            let readRole = AuthorizationPolicy(
                roleName: role.name,
                actionOnResource: readRoleActionOnResource,
                actionOnResourceValue: true)
            
            
            let policySaveResults: [Future<AuthorizationPolicy>] = [
                readAuthPolicy.save(on: conn),
                writeAuthPolicy.save(on: conn),
                readRole.save(on: conn)
            ]
            return policySaveResults.flatten(on: conn).transform(to: ())
        }
        
    }
    
    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return .done(on: conn)
    }
}
