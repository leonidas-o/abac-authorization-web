import Vapor
import Redis
import Foundation
import ABACAuthorization

protocol CacheStore: ServiceType, ABACCacheStore {
    func save<E>(key: String, to entity: E) -> Future<Void> where E: Encodable
    func get<D>(key: String, as type: D.Type) -> Future<D?> where D: Decodable
    func returnActiveKeys<D>(to keys: [String], as type: [D].Type) -> Future<[D]> where D: Decodable
    func setExpiration(forKey key: String, afterSeconds seconds: Int) -> Future<Int>
    func delete(key: String) -> Future<Void>
    func delete(keys: [String]) -> Future<Void>
    func timeToLive(key: String) -> Future<Int>
}


final class RedisStore: CacheStore {
    
    let db: RedisDatabase.ConnectionPool
    
    init(_ db: RedisDatabase.ConnectionPool) {
        self.db = db
    }
    
    
    // MARK: - JSON Storage
    
    func save<E>(key: String, to entity: E) -> Future<Void> where E: Encodable {
        return db.withConnection{ conn in
            return conn.jsonSet(key, to: entity)
        }
    }
    
    func get<D>(key: String, as type: D.Type) -> Future<D?> where D: Decodable {
        return db.withConnection{ conn in
            return conn.jsonGet(key, as: type)
        }
    }
    
    func returnActiveKeys<D>(to keys: [String], as type: [D].Type) -> Future<[D]> where D: Decodable {
        return db.withConnection{ conn in
            return conn.jsonGet(keys, as: [D].self)
        }
    }
    
    func setExpiration(forKey key: String, afterSeconds seconds: Int) -> Future<Int> {
        return db.withConnection{ conn in
            return conn.expire(key, after: seconds)
        }
    }
    
    func delete(key: String) -> Future<Void> {
        return db.withConnection{ conn in
            return conn.delete(key)
        }
    }
    
    func delete(keys: [String]) -> Future<Void> {
        return db.withConnection{ conn in
            if !keys.isEmpty {
                return conn.delete(keys).transform(to: ())
            } else {
                return conn.future()
            }
        }
    }
    
    func timeToLive(key: String) -> Future<Int> {
        return db.withConnection{ conn in
            return conn.ttl(key)
        }
    }
    
    
    // MARK: - Hash Storage
    
    // NOT USED, NOT IN CACHESTORE PROTOCOL, NO TESTS
    func getHash<D>(key: String, field: String, as type: D.Type) -> Future<D?> where D: Decodable {
        return db.withConnection{ conn in
            return conn.jsonHGet(key, field: field, as: type)
        }
    }
    
}



// MARK: - Extensions

extension RedisStore {
    static func makeService(for container: Container) throws -> Self {
        return .init(try container.connectionPool(to: .redis))
    }
}




extension RedisClient {
    /// Returns if field is an existing field in the redis db.
    /// - Returns: 1 if the key exists. 0 if the key does not exist.
    public func exists(_ key: String) -> Future<Bool> {
        // EXISTS key
        let args = [RedisData(bulk: key)]
        return command("EXISTS", args).map(to: Bool.self) { data in
            guard let value = data.int else {
                throw RedisError(identifier: "exists", reason: "Could not convert resp to int.")
            }
            return value != 0
        }
    }
    
    /// Gets keys as decodable type.
    public func jsonGet<D>(_ keys: [String], as type: [D].Type) -> Future<[D]> where D: Decodable {
        return get(keys, as: Data.self).thenThrowing { data in
            return try data.compactMap { data in
                return try JSONDecoder().decode(D.self, from: data)
            }
        }
    }
    
    /// Gets keys as `RedisDataConvertible` type.
    public func get<D>(_ keys: [String], as type: D.Type) -> Future<[D]> where D: RedisDataConvertible {
        return mget(keys).map(to: [D].self) { arrayData in
            var arrayResult: [D] = []
            for data in arrayData {
                if !data.isNull {
                    arrayResult.append(try D.convertFromRedisData(data))
                }
            }
            return arrayResult
        }
    }
    
    /// Returns Time To Live of an existing field in the redis db.
    /// - Returns: TTL if the key exists. Negative value in order to signal an error.
    public func ttl(_ key: String) -> Future<Int> {
        let args = [RedisData(bulk: key)]
        return command("TTL", args).map(to: Int.self) { data in
            guard let value = data.int else {
                throw RedisError(identifier: "ttl", reason: "Could not convert resp to int.")
            }
            return value
        }
    }
    
    
    /// Gets hash as a decodable type.
    public func jsonHGet<D>(_ key: String, field: String, as type: D.Type) -> Future<D?> where D: Decodable {
        return hget(key, field: field, as: Data.self).thenThrowing{ data in
            return try data.flatMap{ data in
                return try JSONDecoder().decode(D.self, from: data)
            }
        }
    }
    
}
