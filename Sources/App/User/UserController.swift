import Vapor
import ABACAuthorization

protocol UserPersistenceRepo {
    // User
    func getAllUsersWithRoles() async throws -> [UserModel]
    func get(_ userId: UserModel.IDValue) async throws -> UserModel?
    func getWithRoles(_ userId: UserModel.IDValue) async throws -> UserModel?
    func get(byEmail email: String) async throws -> UserModel?
    func save(_ user: UserModel) async throws
    func createUser(fromUserData userData: UserData) async throws -> UserModel
    func updateUser(fromUserData userData: UserData) async throws -> UserModel
    func updateUserInformation(_ user: UserModel, _ updatedUser: User.Public) async throws
    func remove(_ user: UserModel) async throws
    func remove(_ userId: UserModel.IDValue) async throws
    // Role
    func addRole(_ role: RoleModel, to user: UserModel) async throws
    func getAllRoles(_ user: UserModel) async throws -> [RoleModel]
    func getAllRoles(_ userId: UserModel.IDValue) async throws -> [RoleModel]
    func removeRole(_ role: RoleModel, from user: UserModel) async throws
    func removeAllRoles(_ user: UserModel) async throws
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
    
    func apiGetAll(_ req: Request) async throws -> [UserData.Public] {
        let users = try await req.userRepo.getAllUsersWithRoles()
        return users.map {
            UserData.Public(user: $0.convertToUserPublic(),
                            roles: $0.roles.map {  $0.convertToRole() })
        }
    }
    
    
    func apiGet(_ req: Request) async throws -> UserData.Public {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let user = try await req.userRepo.getWithRoles(userId) else {
            throw Abort(.badRequest)
        }
        return UserData.Public(user: user.convertToUserPublic(),
                               roles: user.roles.map { $0.convertToRole() })
    }
    
    
    func apiCreate(_ req: Request) async throws -> User.Public {
        var userData = try req.content.decode(UserData.self)
        userData.user.password = try Bcrypt.hash(userData.user.password)
        
        let user = try await req.userRepo.createUser(fromUserData: userData)
        return user.convertToUserPublic()
    }
    
    
    func apiUpdate(_ req: Request) async throws -> UserData.Public {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let updatedUser = try req.content.decode(User.Public.self)
        
        guard let user = try await req.userRepo.get(userId) else {
            throw Abort(.badRequest)
        }
        async let userUpdate: () = req.userRepo.updateUserInformation(user, updatedUser)
        async let cacheGet = req.cacheRepo.get(key: user.cachedAccessToken ?? "", as: AccessData.self)
        
        guard let accessTokenString = user.cachedAccessToken,
        let cachedAccessData = try await cacheGet else {
            throw Abort(.internalServerError)
        }
        _ = try await userUpdate
        let updatedUserData = UserData(user: user.convertToUser(),
                                       roles: cachedAccessData.userData.roles)
        try await updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
        return updatedUserData.convertToUserDataPublic()
    }
    
    
    func apiDelete(_ req: Request) async throws -> HTTPStatus {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let user = try await req.userRepo.get(userId) else {
            throw Abort(.badRequest)
        }
        try await req.userRepo.remove(user)
        guard let accessTokenString = user.cachedAccessToken else {
            throw Abort(.internalServerError)
        }
        _ = try await req.cacheRepo.delete(key: accessTokenString)
        return .noContent
    }
    
    
    
    // MARK: Siblings Relationships
    
    func apiAddRole(_ req: Request) async throws -> HTTPStatus {
        guard let userId = req.parameters.get("userId", as: UUID.self),
              let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        
        async let user = req.userRepo.get(userId)
        async let role = req.roleRepo.get(roleId)
        guard let user = try await user,
              let role = try await role else {
            throw Abort(.badRequest)
        }
        
        async let addRole: () = req.userRepo.addRole(role, to: user)
        async let cacheGet = req.cacheRepo.get(key: user.cachedAccessToken ?? "", as: AccessData.self)
        guard let cachedAccessData = try await cacheGet else {
            throw Abort(.internalServerError)
        }
        try await addRole
        var roles = cachedAccessData.userData.roles
        roles.append(role.convertToRole())
    
        guard let accessTokenString = user.cachedAccessToken else {
            throw Abort(.internalServerError)
        }
        let updatedUserData = UserData(user: user.convertToUser(),
                                       roles: roles)
        try await updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
        return .created
    }
    
    
    func apiGetRole(_ req: Request) async throws -> [Role] {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let roles = try await req.userRepo.getAllRoles(userId)
        return roles.map { $0.convertToRole() }
    }
    
    
    func apiRemoveRole(_ req: Request) async throws -> HTTPStatus {
        guard let userId = req.parameters.get("userId", as: UUID.self),
              let roleId = req.parameters.get("roleId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        async let user = req.userRepo.get(userId)
        async let role = req.roleRepo.get(roleId)
        guard let user = try await user,
              let role = try await role else {
            throw Abort(.badRequest)
        }
        async let removeRole: () = req.userRepo.removeRole(role, from: user)
        async let cacheGet = req.cacheRepo.get(key: user.cachedAccessToken ?? "", as: AccessData.self)
        guard let cachedAccessData = try await cacheGet else {
            throw Abort(.internalServerError)
        }
        try await removeRole
        
        var roles = cachedAccessData.userData.roles
        roles.removeAll { $0 == role.convertToRole() }
    
        guard let accessTokenString = user.cachedAccessToken else {
            throw Abort(.internalServerError)
        }
        let updatedUserData = UserData(user: user.convertToUser(),
                                       roles: roles)
        try await updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
        return .noContent
    }
    
    
    // This handler has no route, it's not accessible
    func apiRemoveAllRoles(_ req: Request) async throws -> HTTPStatus {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let user = try await req.userRepo.get(userId) else {
            throw Abort(.badRequest)
        }
        try await req.userRepo.removeAllRoles(user)
        guard let accessTokenString = user.cachedAccessToken else {
            throw Abort(.internalServerError)
        }
        let updatedUserData = UserData(user: user.convertToUser(), roles: [])
        try await updateCachedAccessData(req, forToken: accessTokenString, userData: updatedUserData)
        return .noContent
    }
    
    
    
    // MARK: External
    
    func apiGetMyUser(_ req: Request) throws -> User.Public {
        let cachedUser = try req.auth.require(UserModel.self)
        return cachedUser.convertToUserPublic()
    }
    
    func apiUpdateMyUser(_ req: Request) async throws -> UserData.Public {
        guard let accessToken = req.headers.bearerAuthorization else {
            throw Abort(HTTPResponseStatus.unauthorized)
        }
        let user = try req.auth.require(UserModel.self)
        let updatedUser = try req.content.decode(User.Public.self)
        
        try await req.userRepo.updateUserInformation(user, updatedUser)
        guard let cachedAccessData = req.storage.get(UserModelBearerAuthenticator.AccessDataKey.self) else {
            throw Abort(.internalServerError)
        }
        let updatedUserData = UserData(user: user.convertToUser(), roles: cachedAccessData.userData.roles)
        try await updateCachedAccessData(req, forToken: accessToken.token, userData: updatedUserData)
        return updatedUserData.convertToUserDataPublic()
    }
    
    
    func apiDeleteMyUser(_ req: Request) async throws -> HTTPStatus {
        let cachedUser = try req.auth.require(UserModel.self)
        let userId = try cachedUser.requireID()
        guard let user = try await req.userRepo.get(userId) else {
            throw Abort(.internalServerError)
        }
        try await req.userRepo.remove(user)
        _ = try await req.cacheRepo.delete(key: user.cachedAccessToken ?? "")
        return .noContent
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
    
    private func updateCachedAccessData(_ req: Request, forToken token: String, userData: UserData) async throws {
        guard let userId = userData.user.id else {
            throw ModelError.idRequired
        }
        let updatedAccessData = AccessData(token: token, userId: userId, userData: userData)
            .wipeOutUserPassword()
        try await req.cacheRepo.save(key: token, to: updatedAccessData)
    }
    
    
    
    
    
    // MARK: - FRONTEND
    
    func overviewHandlerFE(_ req: Request) async throws -> View {
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)")
        let response = try await req.client.get(uri) { clientReq in
            if let token = auth.accessToken {
                clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
        }
        try response.checkHttpGet(auth)
        let responseDecoded = try response.content.decode([UserData.Public].self)
        let context = UsersOverviewContext(
            title: "Users",
            content: responseDecoded,
            formActionUpdate: "/users/update",
            formActionDelete: "/users/delete",
            error: req.query[String.self, at: "error"])
        return try await req.view.render("user/users", context)
    }
    
    
    func updatePostHandlerFE(_ req: Request) async throws -> View {
        let user = try req.content.decode(User.Public.self)
        guard let userId = user.id else {
            throw Abort(.internalServerError)
        }
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId)")
        let response = try await req.client.get(uri) { clientReq in
            if let token = auth.accessToken {
                clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
        }
        try response.checkHttpGet(auth)
        let responseDecoded = try response.content.decode(UserData.Public.self)
        let context = UpdateUserContext(
            title: "Update User",
            titleRoles: "Update Roles",
            userData: responseDecoded,
            formAction: "update/confirm",
            addRolesURI: "role/add?user-id=\(userId.uuidString)",
            formActionRoleUpdate: "role/update",
            formActionRoleDelete: "role/delete")
        return try await req.view.render("user/user", context)
    }
    
    
    func updateConfirmPostHandlerFE(_ req: Request) async throws -> Response {
        let user = try req.content.decode(User.Public.self)
        guard let userId = user.id else {
            return req.redirect(to: "/users?error=Update failed: UUID corrupt")
        }
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId)")
        let response = try await req.client.put(uri) { clientReq in
            if let token = auth.accessToken {
                clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
            try clientReq.content.encode(user, as: .json)
        }
        do {
            try response.checkHttpPutPostPatch(auth)
            return req.redirect(to: "/users")
        } catch {
            let errorMessage = error.getMessage()
            return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
    
    func deletePostHandlerFE(_ req: Request) async throws -> View {
        let user = try req.content.decode(User.Public.self)
        let context = DeleteUserContext(
            title: "Delete User",
            user: user,
            formAction: "delete/confirm")
        return try await req.view.render("user/userDelete", context)
    }
    
    
    func deleteConfirmPostHandlerFE(_ req: Request) async throws -> Response {
        let user = try req.content.decode(User.Public.self)
        guard let userId = user.id else {
            return req.redirect(to: "/users?error=Delete failed: UUID corrupt")
        }
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId)")
        let response = try await req.client.delete(uri) { clientReq in
            if let token = auth.accessToken {
                clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
        }
        do {
            try response.checkHttpDeleteLogout(auth)
            return req.redirect(to: "/users")
        } catch {
            let errorMessage = error.getMessage()
            return req.redirect(to: "/users?error=\(errorMessage)")
        }
    }
    
    
    
    
    
    // MARK: Relations Handler
    
    // MARK: Create
    
    func addRoleHandlerFE(_ req: Request) async throws -> View {
        guard let userId = req.query[UUID.self, at: "user-id"] else {
            throw Abort(HTTPResponseStatus.badRequest)
        }
        
        let auth = Auth(req: req)
        guard let token = auth.accessToken else { throw Abort(.unauthorized, reason: "Invalid token") }
        let userUri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId.uuidString)")
        let rolesUri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.roles.rawValue)")
        async let userRequest = req.client.get(userUri) { $0.headers.bearerAuthorization = BearerAuthorization(token: token) }
        async let rolesRequest = req.client.get(rolesUri) { $0.headers.bearerAuthorization = BearerAuthorization(token: token) }
        let userResponse = try await userRequest
        let rolesResponse = try await rolesRequest
        try userResponse.checkHttpGet(auth)
        try rolesResponse.checkHttpGet(auth)
        let userResponseDecoded = try userResponse.content.decode(UserData.Public.self)
        let rolesResponseDecoded = try rolesResponse.content.decode([Role].self)
        
        let assignedRoles = Set(userResponseDecoded.roles)
        var possibleRoles = rolesResponseDecoded
        possibleRoles.removeAll(where: { assignedRoles.contains($0) })
        let context = AddRoleContext(
            title: "Add Role",
            user: userResponseDecoded.user,
            possibleRoles: possibleRoles,
            error: req.query[String.self, at: "error"])
        return try await req.view.render("user/role", context)
    }
    
    func addRolePostHandlerFE(_ req: Request) async throws -> Response {
        let role = try req.content.decode(Role.self)
        guard let userId = req.query[UUID.self, at: "user-id"] else {
            throw Abort(.internalServerError)
        }
        
        // TODO: resourceRequest, fetch role via name.
        
        guard let roleId = role.id else {
            throw Abort(.internalServerError)
        }
        let auth = Auth(req: req)
        let uri = URI(string: "\(APIConnection.apiBaseURL)/\(APIResource._apiEntry)/\(APIResource.Resource.users.rawValue)/\(userId.uuidString)/\(APIResource.Resource.roles.rawValue)/\(String(roleId))")
        let response = try await req.client.post(uri) { clientReq in
            if let token = auth.accessToken {
                clientReq.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
        }
        do {
            try response.checkHttpPutPostPatch(auth)
            return req.redirect(to: "/users")
        } catch {
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
