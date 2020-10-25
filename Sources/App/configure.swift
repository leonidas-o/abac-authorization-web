import Fluent
import Vapor
import Redis
import ABACAuthorization
import Leaf


/// Called before your application initializes.
public func configure(_ app: Application) throws {
    
    // MARK: Repositories
    
    app.userRepoFactory.use { req in UserPostgreSQLRepo(db: req.db) }
    app.userRepoFactory.useForApp { app in UserPostgreSQLRepo(db: app.db) }
    app.roleRepoFactory.use { req in RolePostgreSQLRepo(db: req.db) }
    app.roleRepoFactory.useForApp { app in RolePostgreSQLRepo(db: app.db) }
    // ABACAuthorization
    app.abacAuthorizationRepoFactory.use { req in ABACAuthorizationPostgreSQLRepo(db: req.db) }
    app.abacAuthorizationRepoFactory.useForApp { app in ABACAuthorizationPostgreSQLRepo(db: app.db) }
    // specify what repository will be created by cacheRepoFactory
    app.cacheRepoFactory.use { req in RedisRepo(client: req.redis) }
    app.cacheRepoFactory.useForApp { app in RedisRepo(client: app.redis) }
    
    
    
    // MARK: PostgreSQL
    
    let databaseHostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
    let databaseName: String
    let databasePort: Int
    if (app.environment == .testing) {
        databaseName = Environment.get("DATABASE_NAME_TEST") ?? "abacauthweb-test"
        if let testPort = Environment.get("DATABASE_PORT_TEST") {
            databasePort = Int(testPort) ?? 5433
        } else {
            databasePort = 5433
        }
    } else {
        databaseName = Environment.get("DATABASE_NAME") ?? "abacauthweb"
        if let port = Environment.get("DATABASE_PORT") {
            databasePort = Int(port) ?? 5432
        } else {
            databasePort = 5432
        }
    }
    let databaseUsername = Environment.get("DATABASE_USERNAME") ?? "abacauthweb"
    let databasePassword = Environment.get("DATABASE_PASSWORD") ?? "abac12345"
    app.databases.use(.postgres(hostname: databaseHostname,
                                port: databasePort,
                                username: databaseUsername,
                                password: databasePassword,
                                database: databaseName), as: .psql)
    
    // Model lifecycle events
    app.databases.middleware.use(ABACAuthorizationPolicyModelMiddleware())
    app.databases.middleware.use(ABACConditionModelMiddleware())
    
    
    
    // MARK: Redis
    
    let redisHostname = Environment.get("REDIS_HOSTNAME") ?? "localhost"
    let redisPort: Int
    if (app.environment == .testing) {
        redisPort = 6380
    } else {
        redisPort = 6379
    }
    app.redis.configuration = try .init(hostname: redisHostname, port: redisPort)
    
    
    
    // MARK: Sessions
    
    app.sessions.use(.redis)
    app.sessions.configuration.cookieName = "abac-session"
    
    
    
    // MARK: Middleware
    
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    
    
    // MARK:  Model preparation
    
    app.migrations.add(UserModelMigration())
    app.migrations.add(RoleModelMigration())
    app.migrations.add(UserRolePivotMigration())
    app.migrations.add(TodoModelMigration())
    // ABACAuthorization
    app.migrations.add(ABACAuthorizationPolicyModelMigration())
    app.migrations.add(ABACConditionModelMigration())
    
    // data seeding
    app.migrations.add(AdminUserMigration())
    app.migrations.add(DefaultRolesMigration())
    // ABACAuthorization
//    if (app.environment != .testing) {
        app.migrations.add(RestrictedABACAuthorizationPoliciesMigration())
//    }
    
    
    
    // MARK: Leaf

    app.views.use(.leaf)
    app.leaf.cache.isEnabled = app.environment.isRelease
    
    
    
    // MARK: Routes
    
    try routes(app)
    
    
    
    // MARK: Boot
    
    try boot(app)
}
