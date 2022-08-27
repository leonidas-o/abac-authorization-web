import Vapor

struct UserPersistenceRepoFactory {
    var make: ((Request) -> UserPersistenceRepo)?
    mutating func use(_ make: @escaping ((Request) -> UserPersistenceRepo)) {
        self.make = make
    }
    
    var makeForApp: ((Application) -> UserPersistenceRepo)?
    mutating func useForApp(_ make: @escaping ((Application) -> UserPersistenceRepo)) {
        self.makeForApp = make
    }
}



extension Application {
    private struct UserPersistenceRepoKey: StorageKey {
        typealias Value = UserPersistenceRepoFactory
    }

    var userRepoFactory: UserPersistenceRepoFactory {
        get {
            self.storage[UserPersistenceRepoKey.self] ?? .init()
        }
        set {
            self.storage[UserPersistenceRepoKey.self] = newValue
        }
    }
}



extension Application {
    var userRepo: UserPersistenceRepo {
        self.userRepoFactory.makeForApp!(self)
    }
}

extension Request {
    var userRepo: UserPersistenceRepo {
        self.application.userRepoFactory.make!(self)
    }
}
