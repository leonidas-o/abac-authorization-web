import Vapor
import Foundation
import ABACAuthorization


struct ABACAuthorizationPolicyController: RouteCollection {
    
    let cache: CacheRepo
    
    
    func boot(routes: RoutesBuilder) throws {
        // API
        let bearerAuthenticator = UserModelBearerAuthenticator()
        let guardMiddleware = UserModel.guardMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, protectedResources: APIResource._allProtected)
        
        let mainRoute = routes.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.abacAuthPolicies.rawValue)")
        let bulkRoute = routes.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.bulk.rawValue)", "\(APIResource.Resource.abacAuthPolicies.rawValue)")
        
        let gaGroup = mainRoute.grouped(bearerAuthenticator, guardMiddleware, abacMiddleware)
        let gaGroupBulk = bulkRoute.grouped(bearerAuthenticator, guardMiddleware, abacMiddleware)
        
        gaGroup.get(use: apiGetAll)
        gaGroup.get(":policyId", use: apiGet)
        gaGroup.post(use: apiCreate)
        gaGroup.put(":policyId", use: apiUpdate)
        gaGroup.delete(":policyId", use: apiDelete)
        // Relations
        gaGroup.get(":policyId", "\(APIResource.Resource.abacConditions.rawValue)", use: apiGetAllRelatedConditions)
        // Re-create in-memory policies
        gaGroup.put("\(APIResource.Resource.abacAuthPoliciesService.rawValue)", use: _recreateAllInMempryPolocies)
        // Bulk
        gaGroupBulk.post(use: apiCreateBulk)
        
        
        // FRONTEND
        let authorizationPolicyRoute = routes.grouped("authorization-policies")
        let authGroup = authorizationPolicyRoute.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        
        authGroup.get(use: overview)
        authGroup.get("create", use: create)
        authGroup.post("create", use: createPost)
        
        authGroup.post("update", use: updatePost)
        authGroup.post("update", "confirm", use: updateConfirmPost)
        
        authGroup.post("delete", use: deletePost)
        authGroup.post("delete", "confirm", use: deleteConfirmPost)
        
        // Relations
        authGroup.get("condition-value/create", use: createCondition)
        authGroup.post("condition-value/create", use: createConditionPost)
        authGroup.post("condition-value/update", use: updateConditionPost)
        authGroup.post("condition-value/update/confirm", use: updateConditionConfirmPost)
        authGroup.post("condition-value/delete", use: deleteConditionPost)
        authGroup.post("condition-value/delete/confirm", use: deleteConditionConfirmPost)
    }
    
    
    
    
    
    
    // MARK: - API
    
    func apiGetAll(_ req: Request) throws -> EventLoopFuture<[ABACAuthorizationPolicy]> {
        return req.abacAuthorizationRepo.getAllWithConditions().map { policies in
            
            return policies.map { policy -> ABACAuthorizationPolicy in
                let abacConditions = policy.conditions.map { $0.convertToABACCondition() }
                return ABACAuthorizationPolicy(id: policy.id,
                                               roleName: policy.roleName,
                                               actionKey: policy.actionKey,
                                               actionValue: policy.actionValue,
                                               conditions: abacConditions)
            }
        }
    }
    
    
    func apiGet(_ req: Request) throws -> EventLoopFuture<ABACAuthorizationPolicy> {
        guard let policyId = req.parameters.get("policyId", as: ABACAuthorizationPolicyModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        return req.abacAuthorizationRepo.getWithConditions(policyId).unwrap(or: Abort(.badRequest)).map { policy in
            var converted = policy.convertToABACAuthorizationPolicy()
            converted.conditions = policy.conditions.map { $0.convertToABACCondition() }
            return converted
        }
    }
    
    
    func apiCreate(_ req: Request) throws -> EventLoopFuture<ABACAuthorizationPolicy> {
        let content = try req.content.decode(ABACAuthorizationPolicy.self)
        
        let policy = content.convertToABACAuthorizationPolicyModel()
        return req.abacAuthorizationRepo.save(policy)
            .transform(to: policy.convertToABACAuthorizationPolicy())
    }
    
    
    func apiUpdate(_ req: Request) throws -> EventLoopFuture<ABACAuthorizationPolicy> {
        guard let policyId = req.parameters.get("policyId", as: ABACAuthorizationPolicyModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        let updatedAuthPolicy = try req.content.decode(ABACAuthorizationPolicy.self)
        return req.abacAuthorizationRepo.getWithConditions(policyId).unwrap(or: Abort(.badRequest)).flatMap { policy in
            return req.abacAuthorizationRepo.update(policy, updatedPolicy: updatedAuthPolicy).map {
                var converted = policy.convertToABACAuthorizationPolicy()
                converted.conditions = policy.conditions.map { $0.convertToABACCondition() }
                return converted
            }
        }
    }
    
    
    func apiDelete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let policyId = req.parameters.get("policyId", as: ABACAuthorizationPolicyModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        // Fetch model to call delete on model because of
        // https://github.com/vapor/fluent/issues/704
        return req.abacAuthorizationRepo.get(policyId).unwrap(or: Abort(.noContent)).map { policy in
            return req.abacAuthorizationRepo.delete(policy)
        }.transform(to: .noContent)
    }
    
    
    
    // MARK: Relations
    
    func apiGetAllRelatedConditions(_ req: Request) throws -> EventLoopFuture<[ABACCondition]> {
        guard let policyId = req.parameters.get("policyId", as: ABACAuthorizationPolicyModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        return req.abacAuthorizationRepo.getWithConditions(policyId).unwrap(or: Abort(.badRequest)).map { policy in
            return policy.conditions.map { $0.convertToABACCondition() }
        }
    }
    
    
    
    // MARK: ABACAuthorizationPolicyService
    
    func _recreateAllInMempryPolocies(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return req.abacAuthorizationRepo.getAllWithConditions().flatMapThrowing { policies in
            for policy in policies {
                try req.abacAuthorizationPolicyService.addToInMemoryCollection(policy: policy, conditions: policy.conditions)
            }
            return .noContent
        }
    }
    
    
    
    // MARK: Bulk
     
    func apiCreateBulk(_ req: Request) throws -> EventLoopFuture<[ABACAuthorizationPolicy]> {
        let authPolicies = try req.content.decode([ABACAuthorizationPolicy].self).map { policy in
            policy.convertToABACAuthorizationPolicyModel()
        }
        return req.abacAuthorizationRepo.saveBulk(authPolicies).flatMap {
            return req.abacAuthorizationRepo.getAllWithConditions().map { policies in
                return policies.map { $0.convertToABACAuthorizationPolicy() }
            }
        }
    }
    
    
    
    
    
    
    // MARK: - FRONTEND
    
    // MARK: Model Handler
    
    // MARK: Read
    
    func overview(_ req: Request) throws -> EventLoopFuture<View> {
        let authPolicyRequest = ResourceRequest<NoRequestType, [ABACAuthorizationPolicy]>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacAuthPolicies.rawValue)")
        return authPolicyRequest.futureGetAll(req).flatMap { apiResponse in
            let context = AuthorizationPolicyOverviewContext(
                title: "Authorization Policies",
                createAuthPolicyURI: "/authorization-policies/create",
                content: apiResponse,
                formActionUpdate: "/authorization-policies/update",
                formActionDelete: "/authorization-policies/delete",
                error: req.query[String.self, at: "error"])
            return req.view.render("authPolicy/authorizationPolicies", context)
        }
    }
    
    
    
    // MARK: Create
    
    func create(_ req: Request) throws -> EventLoopFuture<View> {
        
        let roleRequest = ResourceRequest<NoRequestType, [Role]>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        return roleRequest.futureGetAll(req).flatMap { apiResponse in
            
            let roleNames = apiResponse.map { $0.name }
            let actions = ABACAPIAction.allCases.map { "\($0)" }
            let resources = APIResource._allProtected
            
            let context = CreateAuthorizationPolicyContext(
                title: "Create Authorization Policy",
                roleNames: roleNames,
                actions: actions,
                resources: resources,
                error: req.query[String.self, at: "error"])
            return req.view.render("authPolicy/authorizationPolicy", context)
        }
        
    }
    
    func createPost(_ req: Request) throws -> EventLoopFuture<Response> {
        let authPolicy = try req.content.decode(ABACAuthorizationPolicy.self)
        let authPolicyRequest = ResourceRequest<ABACAuthorizationPolicy, ABACAuthorizationPolicy>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacAuthPolicies.rawValue)")
        return authPolicyRequest.futureCreate(req, resourceToSave: authPolicy).map { apiResponse in
                return req.redirect(to: "/authorization-policies")
        }.flatMapErrorThrowing { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/authorization-policies/create?error=\(errorMessage)")
        }
    }
    
    
    
    // MARK: Update
    
    func updatePost(_ req: Request) throws -> EventLoopFuture<View> {
        let policy = try req.content.decode(ABACAuthorizationPolicy.self)
        guard let policyId = policy.id else {
            throw Abort(.internalServerError)
        }
        
        let roleRequest = ResourceRequest<NoRequestType, [Role]>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        let authorizationPolicyRequest = ResourceRequest<NoRequestType, ABACAuthorizationPolicy>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacAuthPolicies.rawValue)/\(policyId)")
        
        return roleRequest.futureGetAll(req)
            .and(authorizationPolicyRequest.futureGetAll(req)).flatMap { roles, authPolicy in
            
            let roleNames = roles.map{ $0.name }
            let actions = ABACAPIAction.allCases.map{ "\($0)" }
            let resources = APIResource.Resource.allCases.map{ $0.rawValue }
                
            let actionOnResourceKey: (selectedAction: String, selectedResource: String)
            do {
                actionOnResourceKey = try self.splitActionOnResource(fromKey: policy.actionKey, allActions: actions, allResources: resources)
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
                
            let context = UpdateAuthorizationPolicyContext(
                title: "Update Authorization Policy",
                titleConditions: "Update Condition Values",
                roleNames: roleNames,
                actions: actions,
                resources: resources,
                selectedAction: actionOnResourceKey.selectedAction,
                selectedResource: actionOnResourceKey.selectedResource,
                authPolicy: authPolicy,
                formActionAuthPolicy: "update/confirm",
                createConditionURI: "condition-value/create?auth-policy-id=\(policyId)",
                formActionConditionUpdate: "condition-value/update",
                formActionConditionDelete: "condition-value/delete")
            return req.view.render("authPolicy/authorizationPolicy", context)
        }
    }
    
    
    func updateConfirmPost(_ req: Request) throws -> EventLoopFuture<Response> {
        let authPolicy = try req.content.decode(ABACAuthorizationPolicy.self)
        guard let uuid = authPolicy.id?.uuidString else {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/authorization-policies?error=Update failed: UUID corrupt"))
        }
        let authorizationPolicyRequest = ResourceRequest<ABACAuthorizationPolicy, ABACAuthorizationPolicy>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacAuthPolicies.rawValue)/\(uuid)")
        return authorizationPolicyRequest.futureUpdate(req, resourceToUpdate: authPolicy)
            .map { apiResponse in
                return req.redirect(to: "/authorization-policies")
            }.flatMapErrorThrowing { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
    
    
    // MARK: Delete
    
    func deletePost(_ req: Request) throws -> EventLoopFuture<View> {
        let policy = try req.content.decode(ABACAuthorizationPolicy.self)
        let roleName = policy.roleName // no need to request the api
        let actions = ABACAPIAction.allCases.map { "\($0)" }
        let resources = APIResource.Resource.allCases.map { $0.rawValue }
        let actionOnResourceKey = try self.splitActionOnResource(fromKey: policy.actionKey, allActions: actions, allResources: resources)
        
        let context = DeleteAuthorizationPolicyContext(
            title: "Delete Authorization Policy",
            titleConditions: "Delete Condition Values",
            roleName: roleName,
            actions: actions,
            resources: resources,
            selectedAction: actionOnResourceKey.selectedAction,
            selectedResource: actionOnResourceKey.selectedResource,
            authPolicy: policy,
            formActionAuthPolicy: "delete/confirm")
        return req.view.render("authPolicy/authorizationPolicyDelete", context)
    }
    
    func deleteConfirmPost(_ req: Request) throws -> EventLoopFuture<Response> {
        let authPolicy = try req.content.decode(ABACAuthorizationPolicy.self)
        guard let authPolicyId = authPolicy.id else {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/authorization-policies?error=Delete failed: UUID corrupt"))
        }
        let authPolicyRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacAuthPolicies.rawValue)/\(authPolicyId)")
        return authPolicyRequest.fututeDelete(req).map { apiResponse in
            return req.redirect(to: "/authorization-policies")
            }.flatMapErrorThrowing { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
    
    
    
    
    
    // MARK: Relations Handler
    
    // MARK: Create
    
    func createCondition(_ req: Request) throws -> EventLoopFuture<View> {
        guard let authPolicyUUID = req.query[UUID.self, at: "auth-policy-id"] else {
            throw Abort(HTTPResponseStatus.badRequest)
        }
        let conditionValueTypes = ABACConditionModel.ConditionValueType.allCases.map { $0.rawValue }
        let conditionOperationTypes = ABACConditionModel.ConditionOperationType.allCases.map { $0.rawValue }
        let conditionTypes = ABACConditionModel.ConditionType.allCases.map { $0.rawValue }
        
        let context = CreateABACConditionContext(
            title: "Create Condition Value",
            authPolicyId: authPolicyUUID,
            possibleTypes: conditionValueTypes,
            possibleOperations: conditionOperationTypes,
            possibleLhsRhsTypes: conditionTypes,
            error: req.query[String.self, at: "error"])
        return req.view.render("authPolicy/conditionValue", context)
    }
    
    func createConditionPost(_ req: Request) throws -> EventLoopFuture<Response> {
        let condition = try req.content.decode(ABACCondition.self)
        let conditionValueRequest = ResourceRequest<ABACCondition, ABACCondition>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacConditions.rawValue)")
        return conditionValueRequest.futureCreate(req, resourceToSave: condition)
            .map { apiResponse in
                return req.redirect(to: "/authorization-policies")
            }.flatMapErrorThrowing { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies/create?error=\(errorMessage)")
        }
    }
    
    // MARK: Update
    
    func updateConditionPost(_ req: Request) throws -> EventLoopFuture<View> {
        let condition = try req.content.decode(ABACCondition.self)
        let conditionValueTypes = ABACConditionModel.ConditionValueType.allCases.map { $0.rawValue }
        let conditionOperationTypes = ABACConditionModel.ConditionOperationType.allCases.map { $0.rawValue }
        let conditionLhsRhsTypes = ABACConditionModel.ConditionType.allCases.map { $0.rawValue }
        let context = UpdateABACConditionContext(
            title: "Update Condition Value",
            abacCondition: condition,
            possibleTypes: conditionValueTypes,
            possibleOperations: conditionOperationTypes,
            possibleLhsRhsTypes: conditionLhsRhsTypes,
            formActionConditionValue: "update/confirm")
        return req.view.render("authPolicy/conditionValue", context)
    }
    
    func updateConditionConfirmPost(_ req: Request) throws -> EventLoopFuture<Response> {
        let condition = try req.content.decode(ABACCondition.self)
        guard let uuid = condition.id?.uuidString else {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/authorization-policies?error=Update failed: UUID corrupt"))
        }
        let conditionsRequest = ResourceRequest<ABACCondition, ABACCondition>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacConditions.rawValue)/\(uuid)")
        return conditionsRequest.futureUpdate(req, resourceToUpdate: condition)
            .map { apiResponse in
                return req.redirect(to: "/authorization-policies")
            }.flatMapErrorThrowing { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
    // MARK: Delete
    
    func deleteConditionPost(_ req: Request) throws -> EventLoopFuture<View> {
        let condition = try req.content.decode(ABACCondition.self)
        let conditionValueTypes = [condition.type.rawValue]
        let conditionOperationTypes = [condition.operation.rawValue]
        let conditionLhsRhsTypes = [condition.lhsType.rawValue, condition.rhsType.rawValue]
        let context = UpdateABACConditionContext(
            title: "Delete Condition Value",
            abacCondition: condition,
            possibleTypes: conditionValueTypes,
            possibleOperations: conditionOperationTypes,
            possibleLhsRhsTypes: conditionLhsRhsTypes,
            formActionConditionValue: "delete/confirm")
        return req.view.render("authPolicy/conditionValueDelete", context)
    }
    
    func deleteConditionConfirmPost(_ req: Request) throws -> EventLoopFuture<Response> {
        let condition = try req.content.decode(ABACCondition.self)
        guard let uuid = condition.id?.uuidString else {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/authorization-policies?error=Delete failed: UUID corrupt"))
        }
        let conditionValueRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.abacConditions.rawValue)/\(uuid)")
        return conditionValueRequest.fututeDelete(req).map { apiResponse in
            return req.redirect(to: "/authorization-policies")
        }.flatMapErrorThrowing { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
}


// MARK: - Private helper methods

extension ABACAuthorizationPolicyController {
    private func splitActionOnResource(fromKey policyKey: String, allActions actions: [String], allResources resources: [String]) throws -> (selectedAction: String, selectedResource: String) {
        
        var selectedAction: String?
        for action in actions {
            if policyKey.hasPrefix(action) {
                selectedAction = action
                break
            }
        }
        var selectedResource: String?
        for resource in resources {
            if policyKey.hasSuffix(resource) {
                selectedResource = resource
                break
            }
        }
        
        guard let resource = selectedResource, let action = selectedAction else {
            throw Abort(.internalServerError)
        }
        return (action, resource)
    }
}






struct AuthorizationPolicyOverviewContext: Encodable {
    let title: String
    let createAuthPolicyURI: String
    let content: [ABACAuthorizationPolicy]
    let formActionUpdate: String?
    let formActionDelete: String?
    let error: String?
}

struct CreateAuthorizationPolicyContext: Encodable {
    let title: String
    let roleNames: [String]
    let actions: [String]
    let resources: [String]
    let error: String?
}

struct UpdateAuthorizationPolicyContext: Encodable {
    let title: String
    let titleConditions: String
    let roleNames: [String]
    let actions: [String]
    let resources: [String]
    
    let selectedAction: String
    let selectedResource: String
    let authPolicy: ABACAuthorizationPolicy
    
    let formActionAuthPolicy: String?
    let createConditionURI: String
    let formActionConditionUpdate: String?
    let formActionConditionDelete: String?
    let editing = true
}

struct DeleteAuthorizationPolicyContext: Encodable {
    let title: String
    let titleConditions: String
    let roleName: String
    let actions: [String]
    let resources: [String]
    
    let selectedAction: String
    let selectedResource: String
    let authPolicy: ABACAuthorizationPolicy
    
    let formActionAuthPolicy: String?
}



struct CreateABACConditionContext: Encodable {
    let title: String
    let authPolicyId: UUID
    
    let possibleTypes: [String]
    let possibleOperations: [String]
    let possibleLhsRhsTypes: [String]
    
    let error: String?
}

struct UpdateABACConditionContext: Encodable {
    let title: String
    let abacCondition: ABACCondition
    
    let possibleTypes: [String]
    let possibleOperations: [String]
    let possibleLhsRhsTypes: [String]
    
    let formActionConditionValue: String?
    let editing = true
}
