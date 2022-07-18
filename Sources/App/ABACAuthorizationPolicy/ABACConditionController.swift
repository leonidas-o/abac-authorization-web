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
    
    
    
    func create(_ req: Request) throws -> EventLoopFuture<ABACCondition> {
        let content = try req.content.decode(ABACCondition.self)
        let condition = content.convertToABACConditionModel()
        condition.key = condition.key.isEmpty ? ABACConditionModel.Constant.defaultConditionKey : condition.key
        return req.abacAuthorizationRepo.saveCondition(condition)
            .transform(to: condition.convertToABACCondition())
    }
    
    
    func update(_ req: Request) throws -> EventLoopFuture<ABACCondition> {
        guard let conditionId = req.parameters.get("conditionId", as: ABACConditionModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        let updatedCondition = try req.content.decode(ABACCondition.self)
        
        return req.abacAuthorizationRepo.getCondition(conditionId).unwrap(or: Abort(.badRequest)).flatMap { condition in
            return req.abacAuthorizationRepo.updateCondition(condition, updatedCondition: updatedCondition)
                .transform(to: condition.convertToABACCondition())
        }
    }
    
    
    func delete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let conditionId = req.parameters.get("conditionId", as: ABACConditionModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        // TODO: check if it can be deleted directly or
        // you have to condition.$id.exists = true
        return req.abacAuthorizationRepo.deleteCondition(conditionId)
            .transform(to: .noContent)
    }
    
    
    
    // MARK: - Relations
    
    func getRelatedAuthorizationPolicy(_ req: Request) throws -> EventLoopFuture<ABACAuthorizationPolicy> {
        guard let conditionId = req.parameters.get("conditionId", as: ABACConditionModel.IDValue.self) else {
            throw Abort(.badRequest)
        }
        return req.abacAuthorizationRepo.getConditionWithPolicy(conditionId).unwrap(or: Abort(.badRequest)).map { condition in
            return condition.authorizationPolicy.convertToABACAuthorizationPolicy()
        }
    }
    
}
