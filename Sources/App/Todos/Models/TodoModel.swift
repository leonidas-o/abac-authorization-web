import Vapor
import Fluent

/// A single entry of a todo list.
final class TodoModel: Model {
    
    static let schema = "todo"
    
    /// The unique identifier for this `Todo`.
    @ID(custom: .id) var id: Int?

    /// A title describing what this `Todo` entails.
    @Field(key: "title") var title: String
    
    /// Reference to user that owns this TODO.
    @Parent(key: "user_id") var user: UserModel

    
    init() {}
    
    /// Creates a new `Todo`.
    init(id: Int? = nil, title: String, userId: UserModel.IDValue) {
        self.id = id
        self.title = title
        self.$user.id = userId
    }
}



// MARK: - General Conformance

/// Allows `Todo` to be encoded to and decoded from HTTP messages.
extension TodoModel: Content { }


// MARK: - DTO Conversion




// MARK: - Migration

/// Allows `Todo` to be used as a Fluent migration.
struct TodoModelMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("todo")
        .field(.id, .int, .identifier(auto: true), .required)
        .field("title", .string, .required)
        .field("user_id", .uuid, .required, .references("user", "id"))
        .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("todo")
        .delete()
    }
}
