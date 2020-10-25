import Vapor
import Redis
import NIO


struct RedisRepo: CacheRepo {
    
    let client: RedisClient
    
    
    
    // MARK: - JSON Storage
    
    func save<E>(key: String, to entity: E) -> EventLoopFuture<Void> where E: Encodable {
        let redisKey = RedisKey(key)
        do {
            return client.set(redisKey, to: try JSONEncoder().encode(entity))
        } catch {
            return client.eventLoop.makeFailedFuture(error)
        }
    }
    
    
    func get<D>(key: String, as type: D.Type) -> EventLoopFuture<D?> where D: Decodable {
        let redisKey = RedisKey(key)
        return client.get(redisKey, as: Data.self).flatMapThrowing { data in
            return try data.flatMap { data in
                return try JSONDecoder().decode(D.self, from: data)
            }
        }
    }
    
    
    func getExistingKeys<D>(using keys: [String], as type: [D].Type) -> EventLoopFuture<[D]> where D: Decodable {
        let redisKeys = keys.map { RedisKey($0) }
        return client.mget(redisKeys, as: Data.self).flatMapThrowing { data in
            return try data.compactMap { data in
                guard let data = data else {
                    return nil
                }
                return try JSONDecoder().decode(D.self, from: data)
            }
        }
    }
    
    
    func setExpiration(forKey key: String, afterSeconds seconds: Int) -> EventLoopFuture<Bool> {
        let redisKey = RedisKey(key)
        return client.expire(redisKey, after: TimeAmount.seconds(Int64(seconds)))
    }
    
    
    func delete(key: String) -> EventLoopFuture<Int> {
        let redisKey = RedisKey(key)
        return client.delete(redisKey)
    }
    
    
    func delete(keys: [String]) -> EventLoopFuture<Int> {
        let redisKeys = keys.map { RedisKey($0) }
        if !keys.isEmpty {
            return client.delete(redisKeys)
        } else {
            return client.eventLoop.makeSucceededFuture(0)
        }
    
    }
    
    
    func timeToLive(key: String) -> EventLoopFuture<Int> {
        let redisKey = RedisKey(key)
        return client.ttl(redisKey).flatMapThrowing { redisKeyLifeTime in
            if let timeAmount = redisKeyLifeTime.timeAmount {
                return Int(timeAmount.nanoseconds/1000000000)
            } else {
                return 0
            }
        }
    }
    
    
    func exists(_ keys: String...) -> EventLoopFuture<Int> {
        self.exists(keys)
    }
    func exists(_ keys: [String]) -> EventLoopFuture<Int> {
        let redisKey = keys.map { RedisKey($0) }
        return client.exists(redisKey)
    }
    
    
    
    // MARK: - Hash Storage
    
    func getHash<D>(key: String, field: String, as type: D.Type) -> EventLoopFuture<D?> where D: Decodable {
        let redisKey = RedisKey(key)
        return client.hget(field, from: redisKey, as: Data.self).flatMapThrowing { data in
            return try data.flatMap{ data in
                return try JSONDecoder().decode(D.self, from: data)
            }
        }
    }
    
    
    func setHash<E>(_ key: String, field: String, to entity: E) -> EventLoopFuture<Bool> where E: Encodable {
        let redisKey = RedisKey(key)
        do {
            return client.hset(field, to: try JSONEncoder().encode(entity), in: redisKey)
        } catch {
            return client.eventLoop.makeFailedFuture(error)
        }
    }
    
    
    func setMHash<E>(_ key: String, items: Dictionary<String, E>) -> EventLoopFuture<Void> where E: Encodable {
        let redisKey = RedisKey(key)
        do {
            let redisItems  = try items.mapValues { values in
                try JSONEncoder().encode(values)
            }
            return client.hmset(redisItems, in: redisKey)
        } catch {
            return client.eventLoop.makeFailedFuture(error)
        }
    }
    
    
    func deleteHash(_ key: String, fields: String...) -> EventLoopFuture<Int> {
        return deleteHash(key, fields: fields)
    }
    func deleteHash(_ key: String, fields: [String]) -> EventLoopFuture<Int> {
        let redisKey = RedisKey(key)
        return client.hdel(fields, from: redisKey)
    }
    
}
