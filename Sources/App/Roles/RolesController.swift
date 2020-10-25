import Vapor
import Crypto
import ABACAuthorization

protocol RolePersistenceRepo {
    func getAll() -> EventLoopFuture<[RoleModel]>
    func get(_ role: RoleModel) -> EventLoopFuture<RoleModel?>
    func get(_ roleId: RoleModel.IDValue) -> EventLoopFuture<RoleModel?>
    func _getAllUsersFor(_ role: RoleModel) -> EventLoopFuture<[UserModel]>
    func save(_ role: RoleModel) -> EventLoopFuture<Void>
    func update(_ role: RoleModel, _ updatedRole: Role) -> EventLoopFuture<Void>
    func delete(_ roleId: RoleModel.IDValue) -> EventLoopFuture<Void>
    func delete(_ role: RoleModel) -> EventLoopFuture<Void>
}


struct RolesController: RouteCollection {
    
    let cache: CacheRepo
    
    
    func boot(routes: RoutesBuilder) throws {
        let bearerAuthenticator = UserModelBearerAuthenticator()
        let guardMiddleware = UserModel.guardMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, protectedResources: APIResource._allProtected)
        
        // API
        let mainRoute = routes.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.roles.rawValue)")
        let gaGroup = mainRoute.grouped(bearerAuthenticator, guardMiddleware, abacMiddleware)
        
        gaGroup.get(use: apiGetAll)
        gaGroup.get(":roleId", "users", use: apiGetUsers)
        gaGroup.post(use: apiCreate)
        gaGroup.put(":roleId", use: apiUpdate)
        gaGroup.delete(":roleId", use: apiDelete)
        
        
        // FRONTEND
        let rolesRoute = routes.grouped("roles")
        let authGroup = rolesRoute.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        authGroup.get(use: overview)
        
        authGroup.get("create", use: create)
        authGroup.post("create", use: createPost)
    }
  
    
    
    // MARK: - API
    
    func apiGetAll(_ req: Request) throws -> EventLoopFuture<[Role]> {
        return req.roleRepo.getAll().map { roles in
            return roles.map { $0.convertToRole() }
        }
    }
    
    
    func apiGetUsers(_ req: Request) throws -> EventLoopFuture<[User.Public]> {
        guard let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        return req.roleRepo.get(roleId).unwrap(or: Abort(.badRequest)).flatMap { role in
            return req.roleRepo._getAllUsersFor(role).map { users in
                return users.map { $0.convertToUserPublic() }
            }
        }
    }
    
    
    func apiCreate(_ req: Request) throws -> EventLoopFuture<Role> {
        let content = try req.content.decode(Role.self)
        let role = content.convertToRoleModel()
        return req.roleRepo.save(role)
            .transform(to: role.convertToRole())
    }
    
    
    func apiUpdate(_ req: Request) throws -> EventLoopFuture<Role> {
        guard let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        let updatedRole = try req.content.decode(Role.self)
        return req.roleRepo.get(roleId).unwrap(or: Abort(.badRequest)).flatMap { role in
            return req.roleRepo.update(role, updatedRole)
                .transform(to: role.convertToRole())
        }
    }
    
    
    func apiDelete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        return req.roleRepo.delete(roleId)
            .transform(to: .noContent)
    }

    
    
    
    
    
    // MARK: - FRONTEND
    
    // MARK: Model Handler
    
    // MARK: Read
    
    func overview(_ req: Request) throws -> EventLoopFuture<View> {
        let roleRequest = ResourceRequest<NoRequestType, [Role]>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        
        return roleRequest.futureGetAll(req).flatMap { apiResponse in
            let context = RolesOverviewContext(
                title: "Roles",
                content: apiResponse,
                formActionUpdate: "/roles/update",
                formActionDelete: "/roles/delete",
                error: req.query[String.self, at: "error"])
            return req.view.render("role/roles", context)
        }
    }
    
    
    
    // MARK: Create
    
    func create(_ req: Request) throws -> EventLoopFuture<View> {
        let context = CreateRoleContext(
            title: "Create Role",
            error: req.query[String.self, at: "error"])
        return req.view.render("role/role", context)
    }
    
    func createPost(_ req: Request) throws -> EventLoopFuture<Response> {
        let role = try req.content.decode(Role.self)
        let roleRequest = ResourceRequest<Role, Role>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        return roleRequest.futureCreate(req, resourceToSave: role).map { apiResponse in
            return req.redirect(to: "/roles")
        }.flatMapErrorThrowing { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/roles/create?error=\(errorMessage)")
        }
    }
    
}




struct RolesOverviewContext: Encodable {
    let title: String
    let content: [Role]
    let formActionUpdate: String?
    let formActionDelete: String?
    let error: String?
}


struct CreateRoleContext: Encodable {
    let title: String
    let error: String?
}
