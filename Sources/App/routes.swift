import Vapor


/// Register your application's routes here.
func routes(_ app: Application) throws {
    
    try app.register(collection: AuthController(cache: app.cacheRepo))
    try app.register(collection: IndexController())
    try app.register(collection: UserController(cache: app.cacheRepo))
    try app.register(collection: RolesController(cache: app.cacheRepo))
    try app.register(collection: TodoController(cache: app.cacheRepo))
    // ABACAuthorization
    try app.register(collection: ABACAuthorizationPolicyController(cache: app.cacheRepo))
    // ABACConditionController not implemented yet
//    try app.register(collection: ABACConditionController(cache: app.cacheRepo))
}
