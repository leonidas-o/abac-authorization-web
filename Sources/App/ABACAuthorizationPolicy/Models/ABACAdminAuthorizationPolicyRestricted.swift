import Vapor
import Fluent
import ABACAuthorization

struct RestrictedABACAuthorizationPoliciesMigration: AsyncMigration {
    
    let readAuthPolicies = "\(ABACAPIAction.read)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let createAuthPolicies = "\(ABACAPIAction.create)\(APIResource.Resource.abacAuthPolicies.rawValue)"
    let readRoles = "\(ABACAPIAction.read)\(APIResource.Resource.roles.rawValue)"
    let readAuths = "\(ABACAPIAction.read)\(APIResource.Resource.auth.rawValue)"
    
    let updateAuthPolicyServiceActionOnResource = "\(ABACAPIAction.update)\(APIResource.Resource.abacAuthPoliciesService.rawValue)"
    
    func prepare(on database: Database) async throws {
        // Admin
        guard let adminRole = try await RoleModel.query(on: database).filter(\.$name == DefaultRolesMigration.DefaultRole.admin.rawValue).first() else {
            throw Abort(.internalServerError)
        }
        let readAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: adminRole.name,
            actionKey: readAuthPolicies,
            actionValue: true)
        
        let writeAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: adminRole.name,
            actionKey: createAuthPolicies,
            actionValue: true)
        
        let readRole = ABACAuthorizationPolicyModel(
            roleName: adminRole.name,
            actionKey: readRoles,
            actionValue: true)
        
        let readAuth = ABACAuthorizationPolicyModel(
            roleName: adminRole.name,
            actionKey: readAuths,
            actionValue: true)
        
        async let readAuthPolicyResponse: () = readAuthPolicy.save(on: database)
        async let writeAuthPolicyResponse: () = writeAuthPolicy.save(on: database)
        async let readRoleResponse: () = readRole.save(on: database)
        async let readAuthResponse: () = readAuth.save(on: database)
        _ = try await (readAuthPolicyResponse, writeAuthPolicyResponse, readRoleResponse, readAuthResponse)
            
        // SystemBot
        guard let systemBotRole = try await RoleModel.query(on: database).filter(\.$name == DefaultRolesMigration.DefaultRole.systemBot.rawValue).first() else {
            throw Abort(.internalServerError)
        }
        let updateAuthPolicy = ABACAuthorizationPolicyModel(
            roleName: systemBotRole.name,
            actionKey: updateAuthPolicyServiceActionOnResource,
            actionValue: true)
        try await updateAuthPolicy.save(on: database)
    }
    
    
    func revert(on database: Database) async throws {
        // Admin
        guard let adminRole =  try await RoleModel.query(on: database).filter(\.$name == DefaultRolesMigration.DefaultRole.admin.rawValue).first() else {
            throw Abort(.internalServerError)
        }
        async let readAuthPolicyResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == adminRole.name)
            .filter(\.$actionKey == readAuthPolicies)
            .delete()
        async let writeAuthPolicyResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == adminRole.name)
            .filter(\.$actionKey == createAuthPolicies)
            .delete()
        async let readRoleResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == adminRole.name)
            .filter(\.$actionKey == readRoles)
            .delete()
        async let readAuthResponse: () = ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == adminRole.name)
            .filter(\.$actionKey == readAuths)
            .delete()
        _ = try await (readAuthPolicyResponse, writeAuthPolicyResponse, readRoleResponse, readAuthResponse)

        // SystemBot
        guard let systemBotRole = try await RoleModel.query(on: database).filter(\.$name == DefaultRolesMigration.DefaultRole.systemBot.rawValue).first() else {
            throw Abort(.internalServerError)
        }
        try await ABACAuthorizationPolicyModel.query(on: database)
            .filter(\.$roleName == systemBotRole.name)
            .filter(\.$actionKey == updateAuthPolicyServiceActionOnResource)
            .delete()
    }
}
