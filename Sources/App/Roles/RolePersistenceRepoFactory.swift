import Vapor

struct RolePersistenceRepoFactory {
    var make: ((Request) -> RolePersistenceRepo)?
    mutating func use(_ make: @escaping ((Request) -> RolePersistenceRepo)) {
        self.make = make
    }
    
    var makeForApp: ((Application) -> RolePersistenceRepo)?
    mutating func useForApp(_ make: @escaping ((Application) -> RolePersistenceRepo)) {
        self.makeForApp = make
    }
}



extension Application {
    private struct RolePersistenceRepoKey: StorageKey {
        typealias Value = RolePersistenceRepoFactory
    }

    var roleRepoFactory: RolePersistenceRepoFactory {
        get {
            self.storage[RolePersistenceRepoKey.self] ?? .init()
        }
        set {
            self.storage[RolePersistenceRepoKey.self] = newValue
        }
    }
}



extension Application {
    var roleRepo: RolePersistenceRepo {
        self.roleRepoFactory.makeForApp!(self)
    }
}

extension Request {
    var roleRepo: RolePersistenceRepo {
        self.application.roleRepoFactory.make!(self)
    }
}
