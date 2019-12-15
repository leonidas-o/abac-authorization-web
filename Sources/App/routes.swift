import Crypto
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router, _ app: Container) throws {
    
    let cacheStore = try app.make(RedisStore.self)
    let userPersistenceStore = try app.make(UserPostgreSQLStore.self)
    let rolePersistenceStore = try app.make(RolePostgreSQLStore.self)
    let authPolicyPersistenceStore = try app.make(AuthorizationPolicyPersistenceStore.self)
    

    let authController = AuthController(userStore: userPersistenceStore, cache: cacheStore)
    try router.register(collection: authController)
    
    let indexController = IndexController()
    try router.register(collection: indexController)
    
    let usersController = UserController(store: userPersistenceStore, cache: cacheStore)
    try router.register(collection: usersController)
    
    let rolesController = RolesController(store: rolePersistenceStore, cache: cacheStore)
    try router.register(collection: rolesController)

    let authPolicyController = AuthorizationPolicyController(authPolicyStore: authPolicyPersistenceStore, roleStore: rolePersistenceStore, cache: cacheStore)
    try router.register(collection: authPolicyController)
    
    let todosController = TodoController(cache: cacheStore)
    try router.register(collection: todosController)
    
}
