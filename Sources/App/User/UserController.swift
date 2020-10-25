import Vapor
import ABACAuthorization


protocol UserPersistenceRepo {
    // User
    func getAllUsersWithRoles() -> EventLoopFuture<[UserModel]>
    func get(_ userId: UserModel.IDValue) -> EventLoopFuture<UserModel?>
    func getWithRoles(_ userId: UserModel.IDValue) -> EventLoopFuture<UserModel?>
    func get(byEmail email: String) -> EventLoopFuture<UserModel?>
    func save(_ user: UserModel) -> EventLoopFuture<Void>
    func createUser(fromUserData userData: UserData) -> EventLoopFuture<UserModel>
    func updateUser(fromUserData userData: UserData) -> EventLoopFuture<UserModel>
    func updateUserInformation(_ user: UserModel, _ updatedUser: User.Public) -> EventLoopFuture<Void>
    func remove(_ user: UserModel) -> EventLoopFuture<Void>
    func remove(_ userId: UserModel.IDValue) -> EventLoopFuture<Void>
    // Role
    func addRole(_ role: RoleModel, to user: UserModel) -> EventLoopFuture<Void>
    func getAllRoles(_ user: UserModel) -> EventLoopFuture<[RoleModel]>
    func getAllRoles(_ userId: UserModel.IDValue) -> EventLoopFuture<[RoleModel]>
    func removeRole(_ role: RoleModel, from user: UserModel) -> EventLoopFuture<Void>
    func removeAllRoles(_ user: UserModel) -> EventLoopFuture<Void>
}


struct UserController: RouteCollection {
    
    enum Constant {
        static let accessTokenCount = 32
        static let accessTokenExpirationTmp = 60*60*12 //s-m-h-d
        static let accessTokenExpirationDefault = 60*60*24*3 //s-m-h-d
    }
    
    
    let cache: CacheRepo
    
    
    func boot(routes: RoutesBuilder) throws {
        let bearerAuthenticator = UserModelBearerAuthenticator()
        let guardMiddleware = UserModel.guardMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, protectedResources: APIResource._allProtected)
        
        // API
        // Internal
        let usersRoute = routes.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.users.rawValue)")
        let userTGAGroup = usersRoute.grouped(bearerAuthenticator, guardMiddleware, abacMiddleware)
        
        userTGAGroup.get(use: apiGetAll)
        userTGAGroup.get(":userId", use: apiGet)
        userTGAGroup.post(use: apiCreate)
        userTGAGroup.put(":userId", use: apiUpdate)
        userTGAGroup.delete(":userId", use: apiDelete)
        // Siblings Relationships
        userTGAGroup.post(":userId", "roles", ":roleId", use: apiAddRole)
        userTGAGroup.get(":userId", "roles", use: apiGetRole)
        userTGAGroup.delete(":userId", "roles", ":roleId", use: apiRemoveRole)
        
        // External
        let myUserRoute = routes.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.myUser.rawValue)")
        let myUserTGGroup = myUserRoute.grouped(bearerAuthenticator, guardMiddleware)
        
        myUserTGGroup.get(use: apiGetMyUser)
        myUserTGGroup.put(use: apiUpdateMyUser)
        myUserTGGroup.delete(use: apiDeleteMyUser)
        // Siblings Relationships
        myUserTGGroup.get("roles", use: apiGetRoleFromMyUser)
        
        
        
        // FRONTEND
        let usersRouteFE = routes.grouped("users")
        let authGroup = usersRouteFE.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        
        authGroup.get(use: overviewHandlerFE)
        authGroup.post("update", use: updatePostHandlerFE)
        authGroup.post("update", "confirm", use: updateConfirmPostHandlerFE)
        authGroup.post("delete", use: deletePostHandlerFE)
        authGroup.post("delete", "confirm", use: deleteConfirmPostHandlerFE)
        // Relation
        authGroup.get("role", "add", use: addRoleHandlerFE)
        authGroup.post("role", "add", use: addRolePostHandlerFE)
    }
    
    
    
    // MARK: - API
    
    // MARK: Internal
    
    func apiGetAll(_ req: Request) throws -> EventLoopFuture<[UserData.Public]> {
        return req.userRepo.getAllUsersWithRoles().map { users in
            return users.map {
                UserData.Public(user: $0.convertToUserPublic(),
                                roles: $0.roles.map {  $0.convertToRole() })
            }
        }
    }
    
    
    func apiGet(_ req: Request) throws -> EventLoopFuture<UserData.Public> {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return req.userRepo.getWithRoles(userId).unwrap(or: Abort(.badRequest)).map { user in
            return UserData.Public(user: user.convertToUserPublic(),
                                   roles: user.roles.map { $0.convertToRole() })
        }
    }
    
    
    func apiCreate(_ req: Request) throws -> EventLoopFuture<User.Public> {
        var userData = try req.content.decode(UserData.self)
        userData.user.password = try Bcrypt.hash(userData.user.password)
        return req.userRepo.createUser(fromUserData: userData).map { user in
            return user.convertToUserPublic()
        }
    }
    
    
    func apiUpdate(_ req: Request) throws -> EventLoopFuture<UserData.Public> {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let updatedUser = try req.content.decode(User.Public.self)
        
        return req.userRepo.get(userId).unwrap(or: Abort(.badRequest)).flatMap { user in
            return req.userRepo.updateUserInformation(user, updatedUser)
                .and(req.cacheRepo.get(key: user.cachedAccessToken ?? "", as: AccessData.self).unwrap(or: Abort(.internalServerError))).flatMap { _, cachedAccessData in
                
                guard let accessTokenString = user.cachedAccessToken else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
                let updatedUserData = UserData(user: user.convertToUser(),
                                               roles: cachedAccessData.userData.roles)
                return updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
                    .transform(to: updatedUserData.convertToUserDataPublic())
            }
        }
    }
    
    
    func apiDelete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return req.userRepo.get(userId).unwrap(or: Abort(.badRequest)).flatMap { user in
            return req.userRepo.remove(user).flatMap { _ -> EventLoopFuture<Int> in
                guard let accessTokenString = user.cachedAccessToken else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
                return req.cacheRepo.delete(key: accessTokenString)
            }.transform(to: .noContent)
        }
    }
    
    
    
    // MARK: Siblings Relationships
    
    func apiAddRole(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let userId = req.parameters.get("userId", as: UUID.self),
              let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        return req.userRepo.get(userId).unwrap(or: Abort(.badRequest))
            .and(req.roleRepo.get(roleId).unwrap(or: Abort(.badRequest))).flatMap { user, role in
            return req.userRepo.addRole(role, to: user)
                .and(req.cacheRepo.get(key: user.cachedAccessToken ?? "", as: AccessData.self).unwrap(or: Abort(.internalServerError))).flatMap { _, cachedAccessData in
                
                var roles = cachedAccessData.userData.roles
                roles.append(role.convertToRole())
            
                guard let accessTokenString = user.cachedAccessToken else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
                let updatedUserData = UserData(user: user.convertToUser(),
                                               roles: roles)
                return updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
                    .transform(to: .created)
            }
        }
    }
    
    
    func apiGetRole(_ req: Request) throws -> EventLoopFuture<[Role]> {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return req.userRepo.getAllRoles(userId).map { roles in
            return roles.map { $0.convertToRole() }
        }
    }
    
    
    func apiRemoveRole(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let userId = req.parameters.get("userId", as: UUID.self),
              let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        return req.userRepo.get(userId).unwrap(or: Abort(.badRequest))
            .and(req.roleRepo.get(roleId).unwrap(or: Abort(.badRequest))).flatMap { user, role in
            return req.userRepo.removeRole(role, from: user)
                .and(req.cacheRepo.get(key: user.cachedAccessToken ?? "", as: AccessData.self).unwrap(or: Abort(.internalServerError))).flatMap { _, cachedAccessData in
                
                var roles = cachedAccessData.userData.roles
                roles.removeAll { $0 == role.convertToRole() }
            
                guard let accessTokenString = user.cachedAccessToken else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
                let updatedUserData = UserData(user: user.convertToUser(),
                                               roles: roles)
                return updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
                    .transform(to: .noContent)
            }
        }
    }
    
    
    // This handler has no route, it's not accessible, its test
    // is commented out
    func apiRemoveAllRoles(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return req.userRepo.get(userId).unwrap(or: Abort(.badRequest)).flatMap { user in
            return req.userRepo.removeAllRoles(user)
                .transform(to: user)
        }.flatMap { user in
            guard let accessTokenString = user.cachedAccessToken else {
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
            }
            let updatedUserData = UserData(user: user.convertToUser(),
                                           roles: [])
            return updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
//                .transform(to: updatedUserData.convertToUserDataPublic())
                .transform(to: .noContent)
        }
    }
    
    
    
    // MARK: External
    
    func apiGetMyUser(_ req: Request) throws -> User.Public {
        let cachedUser = try req.auth.require(UserModel.self)
        return cachedUser.convertToUserPublic()
    }
    
    func apiUpdateMyUser(_ req: Request) throws -> EventLoopFuture<UserData.Public> {
        guard let accessToken = req.headers.bearerAuthorization else {
            throw Abort(HTTPResponseStatus.unauthorized)
        }
        let user = try req.auth.require(UserModel.self)
        let updatedUser = try req.content.decode(User.Public.self)
        
        return req.userRepo.updateUserInformation(user, updatedUser).flatMap {
            guard let cachedAccessData = req.storage.get(UserModelBearerAuthenticator.AccessDataKey.self) else {
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
            }
            let updatedUserData = UserData(user: user.convertToUser(),
                                    roles: cachedAccessData.userData.roles)
            return updateCachedAccessData(req, forToken: accessToken.token, userData: updatedUserData)
                .transform(to: updatedUserData.convertToUserDataPublic())
        }
    }
    
    
    func apiDeleteMyUser(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let cachedUser = try req.auth.require(UserModel.self)
        let userId = try cachedUser.requireID()
        return req.userRepo.get(userId).unwrap(or: Abort(.internalServerError)).flatMap { user in
            return req.userRepo.remove(user).flatMap {
                return req.cacheRepo.delete(key: user.cachedAccessToken ?? "")
                    .transform(to: .noContent)
            }
        }
    }
    
    
    func apiGetRoleFromMyUser(_ req: Request) throws -> [Role] {
        // from cache
        guard let cachedAccessData = req.storage.get(UserModelBearerAuthenticator.AccessDataKey.self) else {
            throw Abort(.internalServerError)
        }
        return cachedAccessData.userData.roles
        // or from db
//        let user = try req.auth.require(UserModel.self)
//        return req.userRepo.getAllRoles(from: user)
    }
    
    
    
    // MARK: Private helper methods
    
    private func updateCachedAccessData(_ req: Request, forToken token: String, userData: UserData) -> EventLoopFuture<Void> {
        guard let userId = userData.user.id else {
            return req.eventLoop.makeFailedFuture(ModelError.idRequired)
        }
        let updatedAccessData = AccessData(token: token, userId: userId, userData: userData)
            .wipeOutUserPassword()
        return req.cacheRepo.save(key: token, to: updatedAccessData)
    }
    
    
    
    
    
    // MARK: - FRONTEND
    
    func overviewHandlerFE(_ req: Request) throws -> EventLoopFuture<View> {
        let userRequest = ResourceRequest<NoRequestType, [UserData.Public]>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)")
        
        return userRequest.futureGetAll(req).flatMap { apiResponse in
            let context = UsersOverviewContext(
                title: "Users",
                content: apiResponse,
                formActionUpdate: "/users/update",
                formActionDelete: "/users/delete",
                error: req.query[String.self, at: "error"])
            return req.view.render("user/users", context)
        }
    }
    
    
    func updatePostHandlerFE(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try req.content.decode(User.Public.self)
        guard let userId = user.id else {
            throw Abort(.internalServerError)
        }
        let userRequest = ResourceRequest<NoRequestType, UserData.Public>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId)")
        return userRequest.futureGetAll(req).flatMap { apiResponse in
            
            let context = UpdateUserContext(
                title: "Update User",
                titleRoles: "Update Roles",
                userData: apiResponse,
                formAction: "update/confirm",
                addRolesURI: "role/add?user-id=\(userId.uuidString)",
                formActionRoleUpdate: "role/update",
                formActionRoleDelete: "role/delete")
            return req.view.render("user/user", context)
        }
    }
    
    
    func updateConfirmPostHandlerFE(_ req: Request) throws -> EventLoopFuture<Response> {
        let user = try req.content.decode(User.Public.self)
        guard let userId = user.id else {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/users?error=Update failed: UUID corrupt"))
        }
        let userRequest = ResourceRequest<User.Public, UserData.Public>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId)")
        return userRequest.futureUpdate(req, resourceToUpdate: user)
            .map { apiResponse in
                return req.redirect(to: "/users")
            }.flatMapErrorThrowing { error in
                let errorMessage = error.getMessage()
                return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
    
    func deletePostHandlerFE(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try req.content.decode(User.Public.self)
        let context = DeleteUserContext(
            title: "Delete User",
            user: user,
            formAction: "delete/confirm")
        return req.view.render("user/userDelete", context)
    }
    
    
    func deleteConfirmPostHandlerFE(_ req: Request) throws -> EventLoopFuture<Response> {
        let user = try req.content.decode(User.Public.self)
        guard let userId = user.id else {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/users?error=Delete failed: UUID corrupt"))
        }
        let userRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/api/users/\(userId)")
        return userRequest.fututeDelete(req).map { apiResponse in
            return req.redirect(to: "/users")
        }.flatMapErrorThrowing { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
    
    
    
    
    // MARK: Relations Handler
    
    // MARK: Create
    
    func addRoleHandlerFE(_ req: Request) throws -> EventLoopFuture<View> {
        guard let userId = req.query[UUID.self, at: "user-id"] else {
            throw Abort(HTTPResponseStatus.badRequest)
        }
        let userRequest = ResourceRequest<NoRequestType, UserData.Public>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId.uuidString)")
        let rolesRequest = ResourceRequest<NoRequestType, [Role]>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        
        return userRequest.futureGetAll(req)
            .and(rolesRequest.futureGetAll(req)).flatMap { userData, roles in
            
            let assignedRoles = Set(userData.roles)
            var possibleRoles = roles
            possibleRoles.removeAll(where: { assignedRoles.contains($0) })
            
            let context = AddRoleContext(
                title: "Add Role",
                user: userData.user,
                possibleRoles: possibleRoles,
                error: req.query[String.self, at: "error"])
            return req.view.render("user/role", context)
        }
    }
    
    func addRolePostHandlerFE(_ req: Request) throws -> EventLoopFuture<Response> {
        let role = try req.content.decode(Role.self)
        guard let userId = req.query[UUID.self, at: "user-id"] else {
            throw Abort(.internalServerError)
        }
        
        // TODO: resourceRequest, fetch role via name.
        
        guard let roleId = role.id else {
            throw Abort(.internalServerError)
        }
        let noRequestType = NoRequestType()
        
        let addRoleRequest = ResourceRequest<NoRequestType, StatusCodeResponseType>(resourcePath: "/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId.uuidString)/\(APIResource.Resource.roles.rawValue)/\(String(roleId))")
        
        return addRoleRequest.futureCreateWithoutResponseData(req, resourceToSave: noRequestType).map{ apiResponse in
            return req.redirect(to: "/users")
        }.flatMapErrorThrowing { error in
            let errorMessage = error.getMessage()
            return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
}



struct UsersOverviewContext: Encodable {
    let title: String
    let content: [UserData.Public]
    let formActionUpdate: String
    let formActionDelete: String
    let error: String?
}

struct UpdateUserContext: Encodable {
    let title: String
    let titleRoles: String
    let userData: UserData.Public
    
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
