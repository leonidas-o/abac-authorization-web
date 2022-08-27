import Vapor
import ABACAuthorization

struct ABACConditionController: RouteCollection {
    
    let cache: CacheRepo
    
    
    func boot(routes: RoutesBuilder) throws {
        let bearerAuthenticator = UserModelBearerAuthenticator()
        let guardMiddleware = UserModel.guardMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, protectedResources: APIResource._allProtected)
        let mainRoute = routes.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.abacConditions.rawValue)")
        let gaGroup = mainRoute.grouped(bearerAuthenticator, guardMiddleware, abacMiddleware)
        
        gaGroup.post(use: create)
        gaGroup.put(":conditionId", use: update)
        gaGroup.delete(":conditionId", use: delete)
        // Relations
        gaGroup.get(":conditionId", "\(APIResource.Resource.abacAuthPolicies.rawValue)", use: getRelatedAuthorizationPolicy)
    }
    
    
    
    func create(_ req: Request) async throws -> ABACCondition {
        let content = try req.content.decode(ABACCondition.self)
        let condition = content.convertToABACConditionModel()
        condition.key = condition.key.isEmpty ? ABACConditionModel.Constant.defaultConditionKey : condition.key
        try await req.abacAuthorizationRepo.saveCondition(condition)
        return condition.convertToABACCondition()
    }
    
    
    func update(_ req: Request) async throws -> ABACCondition {
        guard let conditionId = req.parameters.get("conditionId", as: ABACConditionModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        let updatedCondition = try req.content.decode(ABACCondition.self)
        
        guard let condition = try await req.abacAuthorizationRepo.getCondition(conditionId) else {
            throw Abort(.badRequest)
        }
        try await req.abacAuthorizationRepo.updateCondition(condition, updatedCondition: updatedCondition)
        return condition.convertToABACCondition()
    }
    
    
    func delete(_ req: Request) async throws -> HTTPStatus {
        guard let conditionId = req.parameters.get("conditionId", as: ABACConditionModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        // TODO: check if it can be deleted directly or
        // you have to condition.$id.exists = true
        try await req.abacAuthorizationRepo.deleteCondition(conditionId)
        return .noContent
    }
    
    
    
    // MARK: - Relations
    
    func getRelatedAuthorizationPolicy(_ req: Request) async throws -> ABACAuthorizationPolicy {
        guard let conditionId = req.parameters.get("conditionId", as: ABACConditionModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        guard let condition = try await req.abacAuthorizationRepo.getConditionWithPolicy(conditionId) else {
            throw Abort(.badRequest)
        }
        return condition.authorizationPolicy.convertToABACAuthorizationPolicy()
    }
    
}
