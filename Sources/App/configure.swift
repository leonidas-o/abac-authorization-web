import Authentication
import FluentPostgreSQL
import Vapor
import Redis
import ABACAuthorization
import Leaf

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentPostgreSQLProvider())
    try services.register(AuthenticationProvider())
    try services.register(LeafProvider())
    try services.register(RedisProvider())

    // Register Repositories
    services.register(UserPostgreSQLStore.self)
    services.register(RedisStore.self)
    services.register(AuthorizationPolicyPostgreSQLStore.self)
    services.register(RolePostgreSQLStore.self)
    
    // Register routes to the router
    // Thread-safe controllers: https://github.com/vapor/vapor/issues/1711
    services.register(Router.self) { container -> EngineRouter in
        let router = EngineRouter.default()
        try routes(router, container)
        return router
    }
    

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(SessionsMiddleware.self) // Enables sessions.
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)


    // Configure a database
    /// Register the configured database to the database config.
    var databases = DatabasesConfig()
    let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
    let databaseName: String
    let databasePort: Int
    if (env == .testing) {
        databaseName = "abacauthweb-test"
        
        if let testPort = Environment.get("DATABASE_PORT") {
            databasePort = Int(testPort) ?? 5433
        } else {
            databasePort = 5433
        }
        
    } else {
        databaseName = "abacauthweb"
        databasePort = 5432
    }
    let databaseConfig = PostgreSQLDatabaseConfig(
        hostname: hostname,
        port: databasePort,
        username: "abacauthweb",
        database: databaseName,
        password: "abac12345")
    let database = PostgreSQLDatabase(config: databaseConfig)
    databases.add(database: database, as: .psql)
    
    // Redis
    var redisConfig = RedisClientConfig()
    let redisPort: Int
    if (env == .testing) {
        redisPort = 6380
    } else {
        redisPort = 6379
    }
    redisConfig.hostname = Environment.get("REDIS_HOSTNAME") ?? "localhost"
    redisConfig.port = redisPort
    let redis = try RedisDatabase(config: redisConfig)
    databases.add(database: redis, as: .redis)

    services.register(databases)

    /// Configure migrations
    var migrations = MigrationConfig()
    // https://forums.swift.org/t/vapor-3-swift-5-2-regression/34764
    migrations.add(model: User.self, database: DatabaseIdentifier<User.Database>.psql)
    migrations.add(model: Role.self, database: DatabaseIdentifier<Role.Database>.psql)
    migrations.add(model: UserRolePivot.self, database: DatabaseIdentifier<UserRolePivot.Database>.psql)
    //migrations.add(model: UserToken.self, database: .psql)
    migrations.add(model: Todo.self, database: DatabaseIdentifier<Todo.Database>.psql)
    migrations.add(model: AuthorizationPolicy.self, database: DatabaseIdentifier<AuthorizationPolicy.Database>.psql)
    migrations.add(model: ConditionValueDB.self, database: DatabaseIdentifier<ConditionValueDB.Database>.psql)
    // Migrations
    migrations.add(migration: AdminUser.self, database: .psql)
    migrations.add(migration: AdminRole.self, database: .psql)
    if (env != .testing) {
        migrations.add(migration: AdminAuthorizationPolicyRestricted.self, database: .psql)
    }
    services.register(migrations)

    
    var commandConfig = CommandConfig.default()
    commandConfig.useFluentCommands()
    services.register(commandConfig)
    
    services.register(InMemoryAuthorizationPolicy.self)
    
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    config.prefer(RedisCache.self, for: KeyedCache.self)
}



//MARK: - ServiceType conformance
// connection pool for all stores
extension Database {
    public typealias ConnectionPool = DatabaseConnectionPool<ConfiguredDatabase<Self>>
}
