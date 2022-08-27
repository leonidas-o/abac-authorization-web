import Vapor
import ABACAuthorization

protocol CacheRepo: ABACCacheRepo {
    func save<E>(key: String, to entity: E) async throws where E: Encodable
    func get<D>(key: String, as type: D.Type) async throws -> D? where D: Decodable
    func getExistingKeys<D>(using keys: [String], as type: [D].Type) async throws-> [D] where D: Decodable
    func setExpiration(forKey key: String, afterSeconds seconds: Int) async throws-> Bool
    func delete(key: String) async throws -> Int
    func delete(keys: [String]) async throws -> Int
    func timeToLive(key: String) async throws -> Int
    func exists(_ keys: String...) async throws -> Int
    func exists(_ keys: [String]) async throws -> Int
    // hash storage
    func getHash<D>(key: String, field: String, as type: D.Type) async throws -> D? where D: Decodable
    func setHash<E>(_ key: String, field: String, to entity: E) async throws -> Bool where E: Encodable
    func setMHash<E>(_ key: String, items: Dictionary<String, E>) async throws -> Void where E: Encodable
    func deleteHash(_ key: String, fields: String...) async throws -> Int
    func deleteHash(_ key: String, fields: [String]) async throws -> Int
}



struct CacheRepoFactory {
    // CacheRepo in Request
    var make: ((Request) -> CacheRepo)?
    mutating func use(_ make: @escaping ((Request) -> CacheRepo)) {
        self.make = make
    }
    
    // CacheRepo in Application
    var makeForApp: ((Application) -> CacheRepo)?
    mutating func useForApp(_ make: @escaping ((Application) -> CacheRepo)) {
        self.makeForApp = make
    }
}



extension Application {
    private struct CacheRepoKey: StorageKey {
        typealias Value = CacheRepoFactory
    }

    var cacheRepoFactory: CacheRepoFactory {
        get {
            self.storage[CacheRepoKey.self] ?? .init()
        }
        set {
            self.storage[CacheRepoKey.self] = newValue
        }
    }
}



extension Application {
    var cacheRepo: CacheRepo {
        self.cacheRepoFactory.makeForApp!(self)
    }
}

extension Request {
    var cacheRepo: CacheRepo {
        self.application.cacheRepoFactory.make!(self)
    }
}
