import Vapor
import Fluent
import ABACAuthorization


struct RestrictedABACAuthorizationPoliciesMigration: Migration {
    
    let readAuthPolicies = "\(ABACAPIAction.read)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let createAuthPolicies = "\(ABACAPIAction.create)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let readRoles = "\(ABACAPIAction.read)\(APIResource.Resource.roles.rawValue)"
    let readAuths = "\(ABACAPIAction.read)\(APIResource.Resource.auth.rawValue)"
    
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        RoleModel.query(on: database).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
            let readAuthPolicy = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: readAuthPolicies,
                actionValue: true)
            
            let writeAuthPolicy = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: createAuthPolicies,
                actionValue: true)
            
            let readRole = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: readRoles,
                actionValue: true)
            
            let readAuth = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: readAuths,
                actionValue: true)
            
            
            let policySaveResults: [EventLoopFuture<Void>] = [
                readAuthPolicy.save(on: database),
                writeAuthPolicy.save(on: database),
                readRole.save(on: database),
                readAuth.save(on: database)
            ]
            return policySaveResults.flatten(on: database.eventLoop)
        }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        RoleModel.query(on: database).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
            let deleteResults = [
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionKey == readAuthPolicies)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionKey == createAuthPolicies)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionKey == readRoles)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionKey == readAuths)
                    .delete(),
            ]
            return deleteResults.flatten(on: database.eventLoop)
        }
    }
}
