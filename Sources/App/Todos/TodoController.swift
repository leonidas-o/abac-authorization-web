import Vapor
import Fluent
import ABACAuthorization


/// Simple todo-list controller.
struct TodoController: RouteCollection {
    
    let cache: CacheRepo
    
    
    func boot(routes: RoutesBuilder) throws {
        let bearerAuthenticator = UserModelBearerAuthenticator()
        let guardMiddleware = UserModel.guardMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, protectedResources: APIResource._allProtected)
        
        // API
        let mainRoute = routes.grouped("\(APIResource._apiEntry)", "\(APIResource.Resource.todos.rawValue)")
        
        
        let tgaGroup = mainRoute.grouped(bearerAuthenticator, guardMiddleware, abacMiddleware)
        
        tgaGroup.get(use: index)
        tgaGroup.post(use: create)
        tgaGroup.delete(":todoId", use: delete)
        
        
        // FRONTEND
        let todoRoute = routes.grouped("todos")
        let authGroup = todoRoute.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        authGroup.get(use: overviewHandler)
        
        
        // if needed same as other frontend crud routes
        /*
        authGroup.get("create", use: createHandler)
        authGroup.post("create", use: createPostHandler)
        
        authGroup.post("update", use: updatePostHandler)
        authGroup.post("update/confirm", use: updateConfirmPostHandler)
        
        authGroup.post("delete", use: deletePostHandler)
        authGroup.post("delete/confirm", use: deleteConfirmPostHandler)
         */
    }
    
    
    
    // MARK: - API
    
    /// Returns a list of all todos for the auth'd user.
    func index(_ req: Request) throws -> EventLoopFuture<[TodoModel]> {
        // fetch auth'd user
        let user = try req.auth.require(UserModel.self)
        let userId = try user.requireID()
        // query all todo's belonging to user
        return TodoModel.query(on: req.db)
            .filter(\.$user.$id == userId).all()
    }

    /// Creates a new todo for the auth'd user.
    func create(_ req: Request) throws -> EventLoopFuture<TodoModel> {
        // fetch auth'd user
        let user = try req.auth.require(UserModel.self)
        
        // decode request content
        let todo = try req.content.decode(CreateTodoRequest.self)
        // save new todo
        let todoModel = try TodoModel(title: todo.title, userId: user.requireID())
        return todoModel.save(on: req.db)
            .transform(to: todoModel)
    }

    /// Deletes an existing todo for the auth'd user.
    func delete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        // fetch auth'd user
        let user = try req.auth.require(UserModel.self)
        
        // decode request parameter (todos/:id)
        guard let todoId = req.parameters.get("todoId", as: Int.self) else {
            throw Abort(.badRequest)
        }
        return TodoModel.query(on: req.db).filter(\.$id == todoId).first().unwrap(or: Abort(.badRequest)).flatMap { todo in
            // ensure the todo being deleted belongs to this user
            do {
                guard try todo.$user.id == user.requireID() else {
                    throw Abort(.forbidden)
                }
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
            // delete model
            return todo.delete(on: req.db)
                .transform(to: .ok)
        }
    }
    
    
    
    
    
    
    // MARK: - FRONTEND
    
    func overviewHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let todoRequest = ResourceRequest<NoRequestType, [CreateTodoRequest]>(resourcePath: "/api/todos")
        return todoRequest.futureGetAll(req).flatMap { apiResponse in
            let context = TodoOverviewContext(
                title: "Todo's",
                content: apiResponse,
                formActionUpdate: "/todos/update",
                formActionDelete: "/todos/delete",
                error: req.query[String.self, at: "error"])
            return req.view.render("todo/todos", context)
        }
    }
    
    // same as other fronted crud handlers
    
    
}



// MARK: Content

/// Represents data required to create a new todo.
struct CreateTodoRequest: Content {
    /// Todo title.
    var title: String
}



// MARK: - Frontend contexts

struct TodoOverviewContext: Encodable {
    let title: String
    let content: [CreateTodoRequest]
    let formActionUpdate: String
    let formActionDelete: String
    let error: String?
}
