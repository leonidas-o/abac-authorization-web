import Vapor
import Crypto
import ABACAuthorization

protocol RolePersistenceRepo {
    func getAll() async throws -> [RoleModel]
    func get(_ role: RoleModel) async throws -> RoleModel?
    func get(_ roleId: RoleModel.IDValue) async throws -> RoleModel?
    func _getAllUsersFor(_ role: RoleModel) async throws -> [UserModel]
    func save(_ role: RoleModel) async throws
    func update(_ role: RoleModel, _ updatedRole: Role) async throws
    func delete(_ roleId: RoleModel.IDValue) async throws
    func delete(_ role: RoleModel) async throws
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
    
    func apiGetAll(_ req: Request) async throws -> [Role] {
        let roles = try await req.roleRepo.getAll()
        return roles.map { $0.convertToRole() }
    }
    
    
    func apiGetUsers(_ req: Request) async throws -> [User.Public] {
        guard let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        guard let role = try await req.roleRepo.get(roleId) else {
            throw Abort(.badRequest)
        }
        let users = try await req.roleRepo._getAllUsersFor(role)
        return users.map { $0.convertToUserPublic() }
    }
    
    
    func apiCreate(_ req: Request) async throws -> Role {
        let content = try req.content.decode(Role.self)
        let role = content.convertToRoleModel()
        try await req.roleRepo.save(role)
        return role.convertToRole()
    }
    
    
    func apiUpdate(_ req: Request) async throws -> Role {
        guard let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        let updatedRole = try req.content.decode(Role.self)
        guard let role = try await req.roleRepo.get(roleId) else {
            throw Abort(.badRequest)
        }
        try await req.roleRepo.update(role, updatedRole)
        return role.convertToRole()
    }
    
    
    func apiDelete(_ req: Request) async throws -> HTTPStatus {
        guard let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        try await req.roleRepo.delete(roleId)
        return .noContent
    }

    
    
    
    
    
    // MARK: - FRONTEND
    
    // MARK: Model Handler
    
    // MARK: Read
    
    func overview(_ req: Request) async throws -> View {
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        let response = try await req.client.get(uri) { clientReq in
            if let token = auth.accessToken {
                clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
        }
        try response.checkHttpGet(auth)
        let responseDecoded = try response.content.decode([Role].self)
        
        let context = RolesOverviewContext(
            title: "Roles",
            content: responseDecoded,
            formActionUpdate: "/roles/update",
            formActionDelete: "/roles/delete",
            error: req.query[String.self, at: "error"])
        return try await req.view.render("role/roles", context)
    }
    
    
    
    // MARK: Create
    
    func create(_ req: Request) async throws -> View {
        let context = CreateRoleContext(
            title: "Create Role",
            error: req.query[String.self, at: "error"])
        return try await req.view.render("role/role", context)
    }
    
    func createPost(_ req: Request) async throws -> Response {
        let role = try req.content.decode(Role.self)
        
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        let response = try await req.client.post(uri) { clientReq in
            if let token = auth.accessToken {
                clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
            try clientReq.content.encode(role, as: .json)
        }
        do {
            try response.checkHttpPutPostPatch(auth)
            return req.redirect(to: "/roles")
        } catch {
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
