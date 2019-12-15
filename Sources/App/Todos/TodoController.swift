import Vapor
import ABACAuthorization
import FluentPostgreSQL

/// Simple todo-list controller.
final class TodoController: RouteCollection {
    
    private let cache: CacheStore
    private let apiResource: ABACAPIResourceable
    
    init(cache: CacheStore) {
        self.cache = cache
        self.apiResource = APIResource()
    }
    
    
    func boot(router: Router) throws {
        // API
        let mainRoute = router.grouped(APIResource._apiEntry, APIResource.Resource.todos.rawValue)
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let abacMiddleware = ABACMiddleware<AccessData>(cache: cache, apiResource: apiResource)
        let tgaGroup = mainRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware, abacMiddleware)
        
        tgaGroup.get(use: index)
        tgaGroup.post(use: create)
        tgaGroup.delete(Todo.parameter, use: delete)
        
        
        // FRONTEND
        let todoRoute = router.grouped("todos")
        let authGroup = todoRoute.grouped(UserAuthSessionsMiddleware(apiUrl: APIConnection.url, redirectPath: "/login"))
        authGroup.get(use: overviewHandler)
        
        
        // Same as other frontend crud routes
        /*
        authGroup.get("create", use: createHandler)
        authGroup.post(CreateTodoRequest.self, at: "create", use: createPostHandler)
        
        authGroup.post(CreateTodoRequest.self, at: "update", use: updatePostHandler)
        authGroup.post(CreateTodoRequest.self, at: "update/confirm", use: updateConfirmPostHandler)
        
        authGroup.post(CreateTodoRequest.self, at: "delete", use: deletePostHandler)
        authGroup.post(CreateTodoRequest.self, at: "delete/confirm", use: deleteConfirmPostHandler)
         */
    }
    
    
    
    // MARK: - API
    
    /// Returns a list of all todos for the auth'd user.
    func index(_ req: Request) throws -> Future<[Todo]> {
        // fetch auth'd user
        let user = try req.requireAuthenticated(User.self)
        
        // query all todo's belonging to user
        return try Todo.query(on: req)
            .filter(\.userID == user.requireID()).all()
    }

    /// Creates a new todo for the auth'd user.
    func create(_ req: Request) throws -> Future<Todo> {
        // fetch auth'd user
        let user = try req.requireAuthenticated(User.self)
        
        // decode request content
        return try req.content.decode(CreateTodoRequest.self).flatMap { todo in
            // save new todo
            return try Todo(title: todo.title, userID: user.requireID())
                .save(on: req)
        }
    }

    /// Deletes an existing todo for the auth'd user.
    func delete(_ req: Request) throws -> Future<HTTPStatus> {
        // fetch auth'd user
        let user = try req.requireAuthenticated(User.self)
        
        // decode request parameter (todos/:id)
        return try req.parameters.next(Todo.self).flatMap { todo -> Future<Void> in
            // ensure the todo being deleted belongs to this user
            guard try todo.userID == user.requireID() else {
                throw Abort(.forbidden)
            }
            
            // delete model
            return todo.delete(on: req)
        }.transform(to: .ok)
    }
    
    
    
    
    
    
    // MARK: - FRONTEND
    
    func overviewHandler(_ req: Request) throws -> Future<View> {
        let todoRequest = ResourceRequest<NoRequestType, [CreateTodoRequest]>(resourcePath: "/api/todos")
        return todoRequest.futureGetAll(on: req).flatMap { apiResponse in
            let context = TodoOverviewContext(
                title: "Todo's",
                content: apiResponse,
                formActionUpdate: "/todos/update",
                formActionDelete: "/todos/delete",
                error: req.query[String.self, at: "error"])
            return try req.view().render("todo/todos", context)
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
