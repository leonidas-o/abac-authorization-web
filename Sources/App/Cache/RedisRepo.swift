import Vapor
import Redis
import NIO

struct RedisRepo: CacheRepo {
    
    let client: RedisClient
    
    
    
    // MARK: - JSON Storage
    
    func save<E>(key: String, to entity: E) async throws where E: Encodable {
        let redisKey = RedisKey(key)
        try await client.set(redisKey, to: try JSONEncoder().encode(entity)).get()
    }
    
    
    
    func get<D>(key: String, as type: D.Type) async throws -> D? where D: Decodable {
        let redisKey = RedisKey(key)
        
        guard let result = try await client.get(redisKey, asJSON: D.self) else {
            return nil
        }
        return result
    }
    
    
    func getExistingKeys<D>(using keys: [String], as type: [D].Type) async throws -> [D] where D: Decodable {
        let redisKeys = keys.map { RedisKey($0) }
        let data = try await client.mget(redisKeys, as: Data.self).get()
        return try data.compactMap { data in
            guard let data = data else {
                return nil
            }
            return try JSONDecoder().decode(D.self, from: data)
        }
    }
    
    
    func setExpiration(forKey key: String, afterSeconds seconds: Int) async throws -> Bool {
        let redisKey = RedisKey(key)
        return try await client.expire(redisKey, after: TimeAmount.seconds(Int64(seconds))).get()
    }
    
    
    func delete(key: String) async throws -> Int {
        let redisKey = RedisKey(key)
        return try await client.delete(redisKey).get()
    }
    
    
    func delete(keys: [String]) async throws -> Int {
        let redisKeys = keys.map { RedisKey($0) }
        if !keys.isEmpty {
            return try await client.delete(redisKeys).get()
        } else {
            return 0
        }
    
    }
    
    
    func timeToLive(key: String) async throws -> Int {
        let redisKey = RedisKey(key)
        let redisKeyLifeTime = try await client.ttl(redisKey).get()
        if let timeAmount = redisKeyLifeTime.timeAmount {
            return Int(timeAmount.nanoseconds/1000000000)
        } else {
            return 0
        }
    }
    
    
    func exists(_ keys: String...) async throws -> Int {
        try await self.exists(keys)
    }
    func exists(_ keys: [String]) async throws -> Int {
        let redisKey = keys.map { RedisKey($0) }
        return try await client.exists(redisKey).get()
    }
    
    
    
    // MARK: - Hash Storage
    
    func getHash<D>(key: String, field: String, as type: D.Type) async throws -> D? where D: Decodable {
        let redisKey = RedisKey(key)
        let data = try await client.hget(field, from: redisKey, as: Data.self).get()
        return try data.flatMap { data in
            return try JSONDecoder().decode(D.self, from: data)
        }
    }
    
    
    func setHash<E>(_ key: String, field: String, to entity: E) async throws -> Bool where E: Encodable {
        let redisKey = RedisKey(key)
        return try await client.hset(field, to: try JSONEncoder().encode(entity), in: redisKey).get()
    }
    
    
    func setMHash<E>(_ key: String, items: Dictionary<String, E>) async throws -> Void where E: Encodable {
        let redisKey = RedisKey(key)
        let redisItems  = try items.mapValues { values in
            try JSONEncoder().encode(values)
        }
        return try await client.hmset(redisItems, in: redisKey).get()
    }
    
    
    func deleteHash(_ key: String, fields: String...) async throws -> Int {
        return try await deleteHash(key, fields: fields)
    }
    func deleteHash(_ key: String, fields: [String]) async throws -> Int {
        let redisKey = RedisKey(key)
        return try await client.hdel(fields, from: redisKey).get()
    }
    
}
