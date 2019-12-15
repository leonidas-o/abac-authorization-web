import Vapor
import Crypto
import ABACAuthorization

protocol UserPersistenceStore: ServiceType {
    // User
    func getAllUsers() -> Future<APIUserResponse>
    func _get(_ user: User) -> Future<User?>
    func get(_ user: User) -> Future<APIUserResponse>
    func _save(_ user: User) -> Future<User>
    func save(_ userData: UserData) -> Future<User>
    func update(_ user: User, _ updatedUser: User.Public) -> Future<UserData>
    func update(_ user: User, _ updatedUserData: APIUserData) -> Future<UserData>
    func delete(_ user: User) -> Future<Void>
    // Role
    func addRole(_ role: Role, to user: User) -> Future<HTTPStatus>
    func getAllRoles() -> Future<APIRoleResponse>
    func getAllRoles(from user: User) -> Future<APIRoleResponse>
    func removeRole(_ role: Role, from user: User) -> Future<HTTPStatus>
    func removeAllRoles(from user: User) -> Future<HTTPStatus>
}

final class UserController: RouteCollection {
    
    private let store: UserPersistenceStore
    private let cache: CacheStore
    private let apiResource: ABACAPIResourceable
    
    enum Constant {
        static let accessTokenCount = 32
        static let accessTokenExpirationTmp = 60*60*12 //s-m-h-d
        static let accessTokenExpirationDefault = 60*60*24*3 //s-m-h-d
    }
    
    init(store: UserPersistenceStore, cache: CacheStore) {
        self.store = store
        self.cache = cache
        self.apiResource = APIResource()
    }
    
    
    
    func boot(router: Router) throws {
        
        // API
        // Internal
        let usersRoute = router.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.users.rawValue)")
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        let userTGAGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware, abacMiddleware)
        userTGAGroup.get(use: getAllHandler)
        userTGAGroup.get(User.parameter, use: getHandler)
        userTGAGroup.post(UserData.self, use: createHandler)
        userTGAGroup.put(User.Public.self, at: User.parameter, use: updateHandler)
        userTGAGroup.delete(User.parameter, use: deleteHandler)
        // Siblings Relationships
        userTGAGroup.post(User.parameter, "roles", Role.parameter, use: addRoleHandler)
        userTGAGroup.get(User.parameter, "roles", use: getRoleHandler)
        userTGAGroup.delete(User.parameter, "roles", Role.parameter, use: removeRoleHandler)
        
        // External
        let myUserRoute = router.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.myUser.rawValue)")
        let myUserTGGroup = myUserRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        myUserTGGroup.get(use: getMyUserHandler)
        myUserTGGroup.put(User.Public.self, use: updateMyUserHandler)
        myUserTGGroup.delete(use: deleteMyUserHandler)
        // Siblings Relationships
        myUserTGGroup.get("roles", use: getRoleFromMyUserHandler)
        
        
        
        // FRONTEND
        let usersRouteFE = router.grouped("users")
        let authGroup = usersRouteFE.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        authGroup.get(use: overviewHandlerFE)
        authGroup.post(User.Public.self, at: "update", use: updatePostHandlerFE)
        authGroup.post(User.Public.self, at: "update/confirm", use: updateConfirmPostHandlerFE)
        
        authGroup.post(User.Public.self, at: "delete", use: deletePostHandlerFE)
        authGroup.post(User.Public.self, at: "delete/confirm", use: deleteConfirmPostHandlerFE)
        
        // Relation
        authGroup.get("role/add", use: addRoleHandlerFE)
        authGroup.post(Role.self, at: "role/add", use: addRolePostHandlerFE)
    }
    
    
    // MARK: - API
    
    // MARK: Internal
    
    func getAllHandler(_ req: Request) throws -> Future<APIUserResponse> {
        return store.getAllUsers()
    }
    
    func getHandler(_ req: Request) throws -> Future<APIUserResponse> {
        return try req.parameters.next(User.self).flatMap{ user in
            return self.store.get(user)
        }
    }
    
    func createHandler(_ req: Request, userData: UserData) throws -> Future<User.Public> {
        userData.user.password = try BCrypt.hash(userData.user.password)
        return store.save(userData).map{ user in
            return user.convertToPublic()
        }
    }
    
    func updateHandler(_ req: Request, updatedUser: User.Public) throws -> Future<APIUserResponse> {
        guard let accessToken = req.http.headers.bearerAuthorization else {
            throw Abort(HTTPResponseStatus.unauthorized)
        }
        return try req.parameters.next(User.self).flatMap{ user in
            return self.store.update(user, updatedUser)
        }.flatMap{ userData in
            
            let updatedAccessData = try AccessData(token: accessToken.token, userID: userData.user.requireID(), userData: userData)
            return self.cache.save(key: accessToken.token, to: updatedAccessData).map { _ in
                let apiUserData = APIUserData(user: userData.user.convertToPublic(), roles: userData.roles)
                return APIUserResponse(type: .one, source: [apiUserData])
            }
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(User.self).flatMap{ user in
            return self.store.delete(user).transform(to: .noContent)
        }
    }
    
    
    
    // MARK: Siblings Relationships
    
    func addRoleHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self, req.parameters.next(User.self), req.parameters.next(Role.self)) { user, role in
            return self.store.addRole(role, to: user)
        }
    }
    
    func getRoleHandler(_ req: Request) throws -> Future<APIRoleResponse> {
        return try req.parameters.next(User.self).flatMap{ user in
            return self.store.getAllRoles(from: user)
        }
    }
    
    func removeRoleHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self, req.parameters.next(User.self), req.parameters.next(Role.self)) { user, role in
            return self.store.removeRole(role, from: user)
        }
    }
    
    // This handler has no route, it's not accessible, its test
    // is commented out
    func removeAllRolesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(User.self).flatMap{ user in
            return self.store.removeAllRoles(from: user)
        }
    }
    
    
    
    // MARK: External
    
    func getMyUserHandler(_ req: Request) throws -> Future<APIUserResponse> {
        let user = try req.requireAuthenticated(User.self)
        return store.get(user)
    }
    
    func updateMyUserHandler(_ req: Request, updatedUser: User.Public) throws -> Future<APIUserResponse> {
        guard let accessToken = req.http.headers.bearerAuthorization else {
            throw Abort(HTTPResponseStatus.unauthorized)
        }
        let user = try req.requireAuthenticated(User.self)
        return self.store.update(user, updatedUser).flatMap{ userData in
            
            let updatedAccessData = try AccessData(token: accessToken.token, userID: userData.user.requireID(), userData: userData)
            return self.cache.save(key: accessToken.token, to: updatedAccessData).map { _ in
                let apiUserData = APIUserData(user: userData.user.convertToPublic(), roles: userData.roles)
                return APIUserResponse(type: .one, source: [apiUserData])
            }
        }
    }
    
    func deleteMyUserHandler(_ req: Request) throws -> Future<HTTPStatus> {
        let user = try req.requireAuthenticated(User.self)
        return self.store.delete(user).transform(to: HTTPStatus.noContent)
    }
    
    func getRoleFromMyUserHandler(_ req: Request) throws -> Future<APIRoleResponse> {
        let user = try req.requireAuthenticated(User.self)
        return self.store.getAllRoles(from: user)
    }
    
   
    
    
    
    
    
    
    // MARK: - FRONTEND
    
    func overviewHandlerFE(_ req: Request) throws -> Future<View> {
        let userRequest = ResourceRequest<NoRequestType, APIUserResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)")
        
        return userRequest.futureGetAll(on: req).flatMap { apiResponse in
            let context = UsersOverviewContext(
                title: "Users",
                content: apiResponse,
                formActionUpdate: "/users/update",
                formActionDelete: "/users/delete",
                error: req.query[String.self, at: "error"])
            return try req.view().render("user/users", context)
        }
    }
    
    
    func updatePostHandlerFE(_ req: Request, user: User.Public) throws -> Future<View> {
        
        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }
        
        let userRequest = ResourceRequest<User.Public, APIUserResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)")
        return userRequest.futureGetAll(on: req).flatMap{ apiResponse in
            guard apiResponse.source.count == 1, let apiUserResponse = apiResponse.source.first else {
                throw Abort(.internalServerError)
            }
            let context = UpdateUserContext(
                title: "Update User",
                titleRoles: "Update Roles",
                userData: apiUserResponse,
                formAction: "update/confirm",
                addRolesURI: "role/add?user-id=\(userID.uuidString)",
                formActionRoleUpdate: "role/update",
                formActionRoleDelete: "role/delete")
            return try req.view().render("user/user", context)
        }
    }
    
    func updateConfirmPostHandlerFE(_ req: Request, user: User.Public) throws -> Future<Response> {
        guard let uuid = user.id?.uuidString else {
            return req.future(req.redirect(to: "/users?error=Update failed: UUID corrupt"))
        }
        let userRequest = ResourceRequest<User.Public, APIUserResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(uuid)")
        return userRequest.futureUpdate(user, on: req)
            .map { apiResponse in
                return req.redirect(to: "/users")
            }.catchMap { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
    
    func deletePostHandlerFE(_ req: Request, user: User.Public) throws -> Future<View> {
        let context = DeleteUserContext(
            title: "Delete User",
            user: user,
            formAction: "delete/confirm")
        return try req.view().render("user/userDelete", context)
    }
    
    func deleteConfirmPostHandlerFE(_ req: Request, user: User.Public) throws -> Future<Response> {
        guard let uuid = user.id?.uuidString else {
            return req.future(req.redirect(to: "/users?error=Delete failed: UUID corrupt"))
        }
        let userRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/api/users/\(uuid)")
        return userRequest.fututeDelete(on: req).map { apiResponse in
            return req.redirect(to: "/users")
        }.catchMap { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
    
    
    
    
    // MARK: Relations Handler
    
    // MARK: Create
    
    func addRoleHandlerFE(_ req: Request) throws -> Future<View> {
        
        guard let userID = req.query[UUID.self, at: "user-id"] else {
            throw Abort(HTTPResponseStatus.badRequest)
        }
        let userRequest = ResourceRequest<NoRequestType, APIUserResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userID.uuidString)")
        let rolesRequest = ResourceRequest<NoRequestType, APIRoleResponse>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        
        return flatMap(to: View.self, userRequest.futureGetAll(on: req), rolesRequest.futureGetAll(on: req)){ userAPIResponse, rolesAPIResponse in
            
            guard userAPIResponse.source.count == 1, let userData = userAPIResponse.source.first else {
                throw Abort(.internalServerError)
            }
            
            let assignedRoles = Set(userData.roles)
            var possibleRoles = rolesAPIResponse.source
            possibleRoles.removeAll(where: { assignedRoles.contains($0) })
            
            let context = AddRoleContext(
                title: "Add Role",
                user: userData.user,
                possibleRoles: possibleRoles,
                error: req.query[String.self, at: "error"])
            return try req.view().render("user/role", context)
        }
    }
    
    func addRolePostHandlerFE(_ req: Request, role: Role) throws -> Future<Response> {
        
        guard let userID = req.query[UUID.self, at: "user-id"] else {
            throw Abort(.internalServerError)
        }
        
        // TODO: resourceRequest, fetch role via name.
        
        guard let roleID = role.id else {
            throw Abort(.internalServerError)
        }
        let noRequestType = NoRequestType()
        
        let addRoleRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userID.uuidString)/\(APIResource.Resource.roles.rawValue)/\(String(roleID))")
        
        return addRoleRequest.futureCreateWithoutResponseData(noRequestType, on: req).map{ apiResponse in
            return req.redirect(to: "/users")
        }.catchMap{ error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
}



struct UsersOverviewContext: Encodable {
    let title: String
    let content: APIUserResponse?
    let formActionUpdate: String
    let formActionDelete: String
    let error: String?
}

struct UpdateUserContext: Encodable {
    let title: String
    let titleRoles: String
    let userData: APIUserData
    
    let formAction: String?
    let addRolesURI: String?
    let formActionRoleUpdate: String?
    let formActionRoleDelete: String?

    
    let editing = true
}

struct DeleteUserContext: Encodable {
    let title: String
    let user: User.Public
    let formAction: String?
}





struct AddRoleContext: Encodable {
    let title: String
    let user: User.Public
    let possibleRoles: [Role]
    
    let error: String?
}
