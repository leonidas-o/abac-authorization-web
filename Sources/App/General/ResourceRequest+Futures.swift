import Vapor
import Foundation

extension ResourceRequest {
    
    func futureLogin(_ req: Request, username: String, password: String) -> EventLoopFuture<ResponseType> {
        let promise = req.eventLoop.makePromise(of: ResponseType.self)
        login(username: username, password: password) { result in
            switch result {
            case .success(let res):
                promise.succeed(res)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func futureLogout(_ req: Request, token: String) -> EventLoopFuture<Int> {
        let promise = req.eventLoop.makePromise(of: Int.self)
        logout(token: token) { result in
            switch result {
            case .success(let res):
                promise.succeed(res)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    
    func futureGetAll(_ req: Request) -> EventLoopFuture<ResponseType> {
        let promise = req.eventLoop.makePromise(of: ResponseType.self)
        getAll(req) { result in
            switch result {
            case .success(let res):
                promise.succeed(res)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func futureCreate(_ req: Request, resourceToSave: RequestType) -> EventLoopFuture<ResponseType> {
        let promise = req.eventLoop.makePromise(of: ResponseType.self)
        create(req, resourceToSave: resourceToSave) { result in
            switch result {
            case .success(let res):
                promise.succeed(res)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    func futureCreateWithoutResponseData(_ req: Request, resourceToSave: RequestType) -> EventLoopFuture<Int> {
        let promise = req.eventLoop.makePromise(of: Int.self)
        createWithoutDataResponse(req, resourceToSave: resourceToSave) { result in
            switch result {
            case .success(let res):
                promise.succeed(res)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func futureUpdate(_ req: Request, resourceToUpdate: RequestType) -> EventLoopFuture<ResponseType> {
        let promise = req.eventLoop.makePromise(of: ResponseType.self)
        update(req, resourceToUpdate: resourceToUpdate) { result in
            switch result {
            case .success(let res):
                promise.succeed(res)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func fututeDelete(_ req: Request) -> EventLoopFuture<Int> {
        let promise = req.eventLoop.makePromise(of: Int.self)
        delete(req) { result in
            switch result {
            case .success(let res):
                promise.succeed(res)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
}
