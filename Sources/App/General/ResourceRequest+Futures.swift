import Vapor
import Foundation

extension ResourceRequest {
    
    func futureLogin(username: String, password: String, on container: Container) -> Future<ResponseType> {
        let promise = container.eventLoop.newPromise(ResponseType.self)
        login(username: username, password: password) { result in
            switch result {
            case .success(let res):
                promise.succeed(result: res)
            case .failure(let error):
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
    func futureLogout(token: String, on container: Container) -> Future<Int> {
        let promise = container.eventLoop.newPromise(Int.self)
        logout(token: token) { result in
            switch result {
            case .success(let res):
                promise.succeed(result: res)
            case .failure(let error):
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
    
    func futureGetAll(on container: Container) -> Future<ResponseType> {
        let promise = container.eventLoop.newPromise(ResponseType.self)
        getAll(on: container) { result in
            switch result {
            case .success(let res):
                promise.succeed(result: res)
            case .failure(let error):
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
    func futureCreate(_ resourceToSave: RequestType, on container: Container) -> Future<ResponseType> {
        let promise = container.eventLoop.newPromise(ResponseType.self)
        create(resourceToSave, on: container) { result in
            switch result {
            case .success(let res):
                promise.succeed(result: res)
            case .failure(let error):
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    func futureCreateWithoutResponseData(_ resourceToSave: RequestType, on container: Container) -> Future<Int> {
        let promise = container.eventLoop.newPromise(Int.self)
        createWithoutDataResponse(resourceToSave, on: container) { result in
            switch result {
            case .success(let res):
                promise.succeed(result: res)
            case .failure(let error):
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
    func futureUpdate(_ resourceToUpdate: RequestType, on container: Container) -> Future<ResponseType> {
        let promise = container.eventLoop.newPromise(ResponseType.self)
        update(resourceToUpdate, on: container) { result in
            switch result {
            case .success(let res):
                promise.succeed(result: res)
            case .failure(let error):
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
    func fututeDelete(on container: Container) -> Future<Int> {
        let promise = container.eventLoop.newPromise(Int.self)
        delete(on: container) { result in
            switch result {
            case .success(let res):
                promise.succeed(result: res)
            case .failure(let error):
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
}
