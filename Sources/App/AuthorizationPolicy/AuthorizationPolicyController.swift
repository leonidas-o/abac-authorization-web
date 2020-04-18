import Vapor
import Foundation
import ABACAuthorization

protocol AuthorizationPolicyPersistenceStore: ServiceType {
    // AuthorizationPolicy
    func save(_ authPolicy: AuthorizationPolicy) -> Future<APIAuthorizationPolicyResponse>
    func saveBulk(_ authPolicies: [AuthorizationPolicy]) -> Future<APIAuthorizationPolicyResponse>
    func getAll() -> Future<APIAuthorizationPolicyResponse>
    func get(_ authPolicy: AuthorizationPolicy) -> Future<APIAuthorizationPolicyResponse>
    func update(_ authPolicy: AuthorizationPolicy, to updatedAuthPolicy: AuthorizationPolicy) -> Future<APIAuthorizationPolicyResponse>
    func delete(_ authPolicy: AuthorizationPolicy) -> Future<Void>
    func delete(_ authPolicies: [AuthorizationPolicy]) -> Future<Void>
    func deleteUsingUniqueKey(_ authPolicies: [AuthorizationPolicy]) -> Future<Void>
    // ConditionValueDB
    func save(_ conditionValueDB: ConditionValueDB) -> Future<APIConditionValueDBResponse>
    func update(_ conditionValueDB: ConditionValueDB, to updatedConditionValueDB: ConditionValueDB) -> Future<APIConditionValueDBResponse>
    func delete(_ conditionValueDB: ConditionValueDB) -> Future<Void>
    func getAllDBConditionValues(of authPolicy: AuthorizationPolicy) -> Future<APIConditionValueDBResponse>
    func getAuthorizationPolicy(for conditionValueDB: ConditionValueDB) -> Future<APIAuthorizationPolicyResponse>
}

final class AuthorizationPolicyController: RouteCollection {
    
    private let authPolicyStore: AuthorizationPolicyPersistenceStore
    private let roleStore: RolePersistenceStore
    private let cache: CacheStore
    private let apiResource: ABACAPIResourceable
    
    init(authPolicyStore: AuthorizationPolicyPersistenceStore, roleStore: RolePersistenceStore, cache: CacheStore) {
        self.authPolicyStore = authPolicyStore
        self.roleStore = roleStore
        self.cache = cache
        self.apiResource = APIResource()
    }
    
    
    
    
    func boot(router: Router) throws {
        
        // API
        let mainRoute = router.grouped(APIResource._apiEntry, APIResource.Resource.authorizationPolicy.rawValue)
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        let tokenAuthGroup = mainRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware, abacMiddleware)
        
        tokenAuthGroup.get(use: getAllHandler)
        tokenAuthGroup.get(AuthorizationPolicy.parameter, use: getHandler)
        tokenAuthGroup.post(AuthorizationPolicy.self, use: createHandler)
        tokenAuthGroup.post([AuthorizationPolicy].self, at: "bulk", use: createBulkHandler)
        tokenAuthGroup.put(AuthorizationPolicy.self, at: AuthorizationPolicy.parameter, use: updateHandler)
        tokenAuthGroup.delete(AuthorizationPolicy.parameter, use: deleteHandler)
        // Relations
        tokenAuthGroup.get(AuthorizationPolicy.parameter, "condition-values", use: getAllRelatedDBConditionValues)
        
        
        // FRONTEND
        let authorizationPolicyRoute = router.grouped("authorization-policies")
        let authGroup = authorizationPolicyRoute.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        authGroup.get(use: overviewHandler)
        
        authGroup.get("create", use: createHandler)
        authGroup.post(APIAuthorizationPolicy.self, at: "create", use: createPostHandler)
        
        authGroup.post(APIAuthorizationPolicy.self, at: "update", use: updatePostHandler)
        authGroup.post(APIAuthorizationPolicy.self, at: "update/confirm", use: updateConfirmPostHandler)
        
        authGroup.post(APIAuthorizationPolicy.self, at: "delete", use: deletePostHandler)
        authGroup.post(APIAuthorizationPolicy.self, at: "delete/confirm", use: deleteConfirmPostHandler)
        
        // Relations
        authGroup.get("condition-value/create", use: createConditionHandler)
        authGroup.post(ConditionValueDB.self, at: "condition-value/create", use: createConditionPostHandler)
        authGroup.post(ConditionValueDB.self, at: "condition-value/update", use: updateConditionPostHandler)
        authGroup.post(ConditionValueDB.self, at: "condition-value/update/confirm", use: updateConditionConfirmPostHandler)
        authGroup.post(ConditionValueDB.self, at: "condition-value/delete", use: deleteConditionPostHandler)
        authGroup.post(ConditionValueDB.self, at: "condition-value/delete/confirm", use: deleteConditionConfirmPostHandler)
        
    }
    
    
    
    
    
    
    // MARK: - API
    
    func getAllHandler(_ req: Request) throws -> Future<APIAuthorizationPolicyResponse> {
        return authPolicyStore.getAll()
    }
    
    func getHandler(_ req: Request) throws -> Future<APIAuthorizationPolicyResponse> {
        return try req.parameters.next(AuthorizationPolicy.self).flatMap{ authPolicy in
            return self.authPolicyStore.get(authPolicy)
        }
    }
    
    func createHandler(_ req: Request, authPolicy: AuthorizationPolicy) throws -> Future<APIAuthorizationPolicyResponse> {
        return authPolicyStore.save(authPolicy)
    }
    
    func createBulkHandler(_ req: Request, authPolicies: [AuthorizationPolicy]) throws -> Future<APIAuthorizationPolicyResponse> {
        return authPolicyStore.saveBulk(authPolicies)
    }
    
    func updateHandler(_ req: Request, updatedAuthPolicy: AuthorizationPolicy) throws -> Future<APIAuthorizationPolicyResponse> {
        return try req.parameters.next(AuthorizationPolicy.self).flatMap{ authPolicy in
            return self.authPolicyStore.update(authPolicy, to: updatedAuthPolicy)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(AuthorizationPolicy.self).flatMap{ authPolicy in
            return self.authPolicyStore.delete(authPolicy).transform(to: .noContent)
        }
    }
    
    // MARK: Relations
    
    func getAllRelatedDBConditionValues(_ req: Request) throws -> Future<APIConditionValueDBResponse> {
        return try req.parameters.next(AuthorizationPolicy.self).flatMap{ authPolicy in
            return self.authPolicyStore.getAllDBConditionValues(of: authPolicy)
        }
    }
    
    
    
    
    
    
    
    
    // MARK: - FRONTEND
    
    // MARK: Model Handler
    
    // MARK: Read
    
    func overviewHandler(_ req: Request) throws -> Future<View> {
        let authPolicyRequest = ResourceRequest<NoRequestType, APIAuthorizationPolicyResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.authorizationPolicy.rawValue)")
        return authPolicyRequest.futureGetAll(on: req).flatMap{ apiResponse in
            let context = AuthorizationPolicyOverviewContext(
                title: "Authorization Policies",
                createAuthPolicyURI: "/authorization-policies/create",
                content: apiResponse,
                formActionUpdate: "/authorization-policies/update",
                formActionDelete: "/authorization-policies/delete",
                error: req.query[String.self, at: "error"])
            return try req.view().render("authPolicy/authorizationPolicies", context)
        }
    }
    
    
    
    // MARK: Create
    
    func createHandler(_ req: Request) throws -> Future<View> {
        
        let roleRequest = ResourceRequest<NoRequestType, APIRoleResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        return roleRequest.futureGetAll(on: req).flatMap{ apiResponse in
            
            let roleNames = apiResponse.source.map{ $0.name }
            let actions = ABACAPIAction.allCases.map{ "\($0)" }
            let resources = APIResource.Resource.allCases.map{ $0.rawValue }
            
            let context = CreateAuthorizationPolicyContext(
                title: "Create Authorization Policy",
                roleNames: roleNames,
                actions: actions,
                resources: resources,
                error: req.query[String.self, at: "error"])
            return try req.view().render("authPolicy/authorizationPolicy", context)
        }
        
    }
    
    func createPostHandler(_ req: Request, authPolicy: APIAuthorizationPolicy) throws -> Future<Response> {
        let authPolicyRequest = ResourceRequest<APIAuthorizationPolicy, APIAuthorizationPolicyResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.authorizationPolicy.rawValue)")
        return authPolicyRequest.futureCreate(authPolicy, on: req).map { apiResponse in
                return req.redirect(to: "/authorization-policies")
        }.catchMap { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/authorization-policies/create?error=\(errorMessage)")
        }
    }
    
    
    
    // MARK: Update
    
    func updatePostHandler(_ req: Request, authPolicy: APIAuthorizationPolicy) throws -> Future<View> {
        
        guard let authPolicyID = authPolicy.id else {
            throw Abort(.internalServerError)
        }
        
        let roleRequest = ResourceRequest<NoRequestType, APIRoleResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        let authorizationPolicyRequest = ResourceRequest<NoRequestType, APIAuthorizationPolicyResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.authorizationPolicy.rawValue)/\(authPolicyID.uuidString)")
        
        return flatMap(to: View.self, roleRequest.futureGetAll(on: req), authorizationPolicyRequest.futureGetAll(on: req)) { roles, authPolicy in
            
            guard authPolicy.source.count == 1, let authPolicyWithConditions = authPolicy.source.first else {
                throw Abort(.internalServerError)
            }
            
            let roleNames = roles.source.map{ $0.name }
            let actions = ABACAPIAction.allCases.map{ "\($0)" }
            let resources = APIResource.Resource.allCases.map{ $0.rawValue }
            let actionOnResourceKey = try self.splitActionOnResource(fromKey: authPolicyWithConditions.actionOnResourceKey, allActions: actions, allResources: resources)
            
            let context = UpdateAuthorizationPolicyContext(
                title: "Update Authorization Policy",
                titleConditions: "Update Condition Values",
                roleNames: roleNames,
                actions: actions,
                resources: resources,
                selectedAction: actionOnResourceKey.selectedAction,
                selectedResource: actionOnResourceKey.selectedResource,
                authPolicy: authPolicyWithConditions,
                formActionAuthPolicy: "update/confirm",
                createConditionURI: "condition-value/create?auth-policy-id=\(authPolicyID.uuidString)",
                formActionConditionUpdate: "condition-value/update",
                formActionConditionDelete: "condition-value/delete")
            return try req.view().render("authPolicy/authorizationPolicy", context)
        }
    }
    
    
    func updateConfirmPostHandler(_ req: Request, authPolicy: APIAuthorizationPolicy) throws -> Future<Response> {
        guard let uuid = authPolicy.id?.uuidString else {
            return req.future(req.redirect(to: "/authorization-policies?error=Update failed: UUID corrupt"))
        }
        let authorizationPolicyRequest = ResourceRequest<APIAuthorizationPolicy, APIAuthorizationPolicyResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.authorizationPolicy.rawValue)/\(uuid)")
        return authorizationPolicyRequest.futureUpdate(authPolicy, on: req)
            .map { apiResponse in
                return req.redirect(to: "/authorization-policies")
            }.catchMap { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
    
    
    // MARK: Delete
    
    func deletePostHandler(_ req: Request, authPolicy: APIAuthorizationPolicy) throws -> Future<View> {
        let roleName = authPolicy.roleName // no need to request the api
        let actions = ABACAPIAction.allCases.map{ "\($0)" }
        let resources = APIResource.Resource.allCases.map{ $0.rawValue }
        let actionOnResourceKey = try self.splitActionOnResource(fromKey: authPolicy.actionOnResourceKey, allActions: actions, allResources: resources)
        
        let context = DeleteAuthorizationPolicyContext(
            title: "Delete Authorization Policy",
            titleConditions: "Delete Condition Values",
            roleName: roleName,
            actions: actions,
            resources: resources,
            selectedAction: actionOnResourceKey.selectedAction,
            selectedResource: actionOnResourceKey.selectedResource,
            authPolicy: authPolicy,
            formActionAuthPolicy: "delete/confirm")
        return try req.view().render("authPolicy/authorizationPolicyDelete", context)
    }
    
    func deleteConfirmPostHandler(_ req: Request, authPolicy: APIAuthorizationPolicy) throws -> Future<Response> {
        guard let uuid = authPolicy.id?.uuidString else {
            return req.future(req.redirect(to: "/authorization-policies?error=Delete failed: UUID corrupt"))
        }
        let authPolicyRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.authorizationPolicy.rawValue)/\(uuid)")
        return authPolicyRequest.fututeDelete(on: req).map { apiResponse in
            return req.redirect(to: "/authorization-policies")
            }.catchMap { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
    
    
    
    
    
    // MARK: Relations Handler
    
    // MARK: Create
    
    func createConditionHandler(_ req: Request) throws -> Future<View> {
        
        guard let authPolicyUUID = req.query[UUID.self, at: "auth-policy-id"] else {
            throw Abort(HTTPResponseStatus.badRequest)
        }
        
        let conditionValueTypes = ConditionValueDB.ConditionValueType.allCases.map { $0.rawValue }
        let conditionOperationTypes = ConditionValueDB.ConditionOperationType.allCases.map { $0.rawValue }
        let conditionLhsRhsTypes = ConditionValueDB.ConditionLhsRhsType.allCases.map { $0.rawValue }
        
        let context = CreateConditionValueContext(
            title: "Create Condition Value",
            authPolicyID: authPolicyUUID,
            possibleTypes: conditionValueTypes,
            possibleOperations: conditionOperationTypes,
            possibleLhsRhsTypes: conditionLhsRhsTypes,
            error: req.query[String.self, at: "error"])
        return try req.view().render("authPolicy/conditionValue", context)
    }
    
    func createConditionPostHandler(_ req: Request, condition: ConditionValueDB) throws -> Future<Response> {
        let conditionValueRequest = ResourceRequest<ConditionValueDB, APIConditionValueDBResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.conditionValueDB.rawValue)")
        return conditionValueRequest.futureCreate(condition, on: req)
            .map { apiResponse in
                return req.redirect(to: "/authorization-policies")
            }.catchMap { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies/create?error=\(errorMessage)")
        }
    }
    
    // MARK: Update
    
    func updateConditionPostHandler(_ req: Request, condition: ConditionValueDB) throws -> Future<View> {
        let conditionValueTypes = ConditionValueDB.ConditionValueType.allCases.map { $0.rawValue }
        let conditionOperationTypes = ConditionValueDB.ConditionOperationType.allCases.map { $0.rawValue }
        let conditionLhsRhsTypes = ConditionValueDB.ConditionLhsRhsType.allCases.map { $0.rawValue }
        let context = UpdateConditionValueContext(
            title: "Update Condition Value",
            conditionValueDB: condition,
            possibleTypes: conditionValueTypes,
            possibleOperations: conditionOperationTypes,
            possibleLhsRhsTypes: conditionLhsRhsTypes,
            formActionConditionValue: "update/confirm")
        return try req.view().render("authPolicy/conditionValue", context)
    }
    
    func updateConditionConfirmPostHandler(_ req: Request, condition: ConditionValueDB) throws -> Future<Response> {
        guard let uuid = condition.id?.uuidString else {
            return req.future(req.redirect(to: "/authorization-policies?error=Update failed: UUID corrupt"))
        }
        let conditionValueDBRequest = ResourceRequest<ConditionValueDB, APIConditionValueDBResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.conditionValueDB.rawValue)/\(uuid)")
        return conditionValueDBRequest.futureUpdate(condition, on: req)
            .map { apiResponse in
                return req.redirect(to: "/authorization-policies")
            }.catchMap { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
    // MARK: Delete
    
    func deleteConditionPostHandler(_ req: Request, condition: ConditionValueDB) throws -> Future<View> {
        let conditionValueTypes = [condition.type.rawValue]
        let conditionOperationTypes = [condition.operation.rawValue]
        let conditionLhsRhsTypes = [condition.lhsType.rawValue, condition.rhsType.rawValue]
        let context = UpdateConditionValueContext(
            title: "Delete Condition Value",
            conditionValueDB: condition,
            possibleTypes: conditionValueTypes,
            possibleOperations: conditionOperationTypes,
            possibleLhsRhsTypes: conditionLhsRhsTypes,
            formActionConditionValue: "delete/confirm")
        return try req.view().render("authPolicy/conditionValueDelete", context)
    }
    
    func deleteConditionConfirmPostHandler(_ req: Request, condition: ConditionValueDB) throws -> Future<Response> {
        guard let uuid = condition.id?.uuidString else {
            return req.future(req.redirect(to: "/authorization-policies?error=Delete failed: UUID corrupt"))
        }
        let conditionValueRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.conditionValueDB.rawValue)/\(uuid)")
        return conditionValueRequest.fututeDelete(on: req).map { apiResponse in
            return req.redirect(to: "/authorization-policies")
        }.catchMap { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/authorization-policies?error=\(errorMessage)")
        }
    }
    
}


// MARK: - Private helper methods

extension AuthorizationPolicyController {
    private func splitActionOnResource(fromKey authPolicyKey: String, allActions actions: [String], allResources resources: [String]) throws -> (selectedAction: String, selectedResource: String) {
        
        var selectedAction: String?
        for action in actions {
            if authPolicyKey.hasPrefix(action) {
                selectedAction = action
                break
            }
        }
        var selectedResource: String?
        for resource in resources {
            if authPolicyKey.hasSuffix(resource) {
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
    let content: APIAuthorizationPolicyResponse?
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
    let authPolicy: APIAuthorizationPolicyWithConditions
    
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
    let authPolicy: APIAuthorizationPolicy
    
    let formActionAuthPolicy: String?
}



struct CreateConditionValueContext: Encodable {
    let title: String
    let authPolicyID: UUID
    
    let possibleTypes: [String]
    let possibleOperations: [String]
    let possibleLhsRhsTypes: [String]
    
    let error: String?
}

struct UpdateConditionValueContext: Encodable {
    let title: String
    let conditionValueDB: ConditionValueDB
    
    let possibleTypes: [String]
    let possibleOperations: [String]
    let possibleLhsRhsTypes: [String]
    
    let formActionConditionValue: String?
    let editing = true
}
