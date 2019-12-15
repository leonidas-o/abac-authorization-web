import Vapor
import Crypto
import ABACAuthorization

protocol RolePersistenceStore: ServiceType {
    func getAll() -> Future<APIRoleResponse>
    func _getAllUsersFor(_ role: Role) -> Future<[User]>
    func save(_ role: Role) -> Future<APIRoleResponse>
    func update(_ role: Role, _ updatedRole: Role) -> EventLoopFuture<APIRoleResponse>
    func delete(_ role: Role) -> EventLoopFuture<Void>
}

struct RolesController: RouteCollection {
    
    private let store: RolePersistenceStore
    private let cache: CacheStore
    private let apiResource: ABACAPIResourceable
    
    init(store: RolePersistenceStore, cache: CacheStore) {
        self.store = store
        self.cache = cache
        self.apiResource = APIResource()
    }
    
    
    func boot(router: Router) throws {
        
        // API
        let mainRoute = router.grouped(APIResource._apiEntry, APIResource.Resource.roles.rawValue)
                
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        let tokenAuthGroup = mainRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware, abacMiddleware)
        
        tokenAuthGroup.get(use: getAllHandler)
        tokenAuthGroup.get(Role.parameter, "users", use: getUsersHandler)
        tokenAuthGroup.post(Role.self, use: createHandler)
        tokenAuthGroup.put(Role.self, at: Role.parameter, use: updateHandler)
        tokenAuthGroup.delete(Role.parameter, use: deleteHandler)
        
        
        // FRONTEND
        let rolesRoute = router.grouped("roles")
        let authGroup = rolesRoute.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        authGroup.get(use: overviewHandler)
        
        authGroup.get("create", use: createHandler)
        authGroup.post(Role.self, at: "create", use: createPostHandler)
    }
  
    
    // MARK: - API
    
    func getAllHandler(_ req: Request) throws -> Future<APIRoleResponse> {
        return store.getAll()
    }
    
    func getUsersHandler(_ req: Request) throws -> Future<[User]> {
        return try req.parameters.next(Role.self).flatMap{ role in
            return self.store._getAllUsersFor(role)
        }
    }
    
    func createHandler(_ req: Request, role: Role) throws -> Future<APIRoleResponse> {
        return store.save(role)
    }
    
    func updateHandler(_ req: Request, updatedRole: Role) throws -> Future<APIRoleResponse> {
        return try req.parameters.next(Role.self).flatMap{ role in
            return self.store.update(role, updatedRole)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Role.self).flatMap{ role in
            self.store.delete(role)
        }.transform(to: .noContent)
    }

    
    
    
    
    
    // MARK: - FRONTEND
    
    // MARK: Model Handler
    
    // MARK: Read
    
    func overviewHandler(_ req: Request) throws -> Future<View> {
        let roleRequest = ResourceRequest<NoRequestType, APIRoleResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        
        return roleRequest.futureGetAll(on: req).flatMap{ apiResponse in
            let context = RolesOverviewContext(
                title: "Roles",
                content: apiResponse,
                formActionUpdate: "/roles/update",
                formActionDelete: "/roles/delete",
                error: req.query[String.self, at: "error"])
            return try req.view().render("role/roles", context)
        }
    }
    
    
    
    // MARK: Create
    
    func createHandler(_ req: Request) throws -> Future<View> {
        let context = CreateRoleContext(
            title: "Create Role",
            error: req.query[String.self, at: "error"])
        return try req.view().render("role/role", context)
    }
    
    func createPostHandler(_ req: Request, role: Role) throws -> Future<Response> {
        let roleRequest = ResourceRequest<Role, APIRoleResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        return roleRequest.futureCreate(role, on: req).map{ apiResponse in
            return req.redirect(to: "/roles")
        }.catchMap{ error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/roles/create?error=\(errorMessage)")
        }
    }
    
}




struct RolesOverviewContext: Encodable {
    let title: String
    let content: APIRoleResponse?
    let formActionUpdate: String?
    let formActionDelete: String?
    let error: String?
}


struct CreateRoleContext: Encodable {
    let title: String
    let error: String?
}
