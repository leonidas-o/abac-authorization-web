import Vapor
import Fluent
import ABACAuthorization


struct RestrictedABACAuthorizationPoliciesMigration: Migration {
    
    let readAuthPolicyActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let createAuthPolicyActionOnResource = "\(ABACAPIAction.create)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let readRoleActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.roles.rawValue)"
    let readAuthActionOnResource = "\(ABACAPIAction.read)\(APIResource.Resource.auth.rawValue)"
    
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        RoleModel.query(on: database).first().unwrap(or: Abort(.internalServerError)).flatMap { role in
            
            let readAuthPolicy = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: readAuthPolicyActionOnResource,
                actionValue: true)
            
            let writeAuthPolicy = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: createAuthPolicyActionOnResource,
                actionValue: true)
            
            let readRole = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: readRoleActionOnResource,
                actionValue: true)
            
            let readAuth = ABACAuthorizationPolicyModel(
                roleName: role.name,
                actionKey: readAuthActionOnResource,
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
                    .filter(\.$actionKey == readAuthPolicyActionOnResource)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionKey == createAuthPolicyActionOnResource)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionKey == readRoleActionOnResource)
                    .delete(),
                ABACAuthorizationPolicyModel.query(on: database)
                    .filter(\.$roleName == role.name)
                    .filter(\.$actionKey == readAuthActionOnResource)
                    .delete(),
            ]
            return deleteResults.flatten(on: database.eventLoop)
        }
    }
}
