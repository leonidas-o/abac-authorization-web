import Vapor


extension Application.Redis {
    public var sessions: Sessions {
        .init(redis: self)
    }
    
    public struct Sessions {
        let redis: Application.Redis
    }
}


extension Application.Redis.Sessions {
    public func driver() -> SessionDriver {
        CacheRepoSessions()
    }
}



extension Application.Sessions.Provider {
    public static var redis: Self {
        Application.Sessions.Provider.init { app in
            app.sessions.use { _ in app.redis.sessions.driver() }
        }
    }
}


private struct CacheRepoSessions: SessionDriver {
        
    func createSession(_ data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        let id = self.generateID()
        return request.cacheRepo.save(key: id.string, to: data)
            .transform(to: id)
    }
    
    func readSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<SessionData?> {
        return request.cacheRepo.get(key: sessionID.string, as: SessionData.self)
    }
    
    func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        return request.cacheRepo.save(key: sessionID.string, to: data)
            .transform(to: sessionID)
    }
    
    func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
        return request.cacheRepo.delete(key: sessionID.string)
            .transform(to: ())
    }
    
    private func generateID() -> SessionID {
        var bytes = Data()
        for _ in 0..<32 {
            bytes.append(.random(in: .min ..< .max))
        }
        return .init(string: bytes.base64EncodedString())
    }
}
