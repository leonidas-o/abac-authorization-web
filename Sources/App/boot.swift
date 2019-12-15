import Vapor
import ABACAuthorization

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    
    let conn = try app.newConnection(to: .psql).wait()
    
    // MARK: Authorization
     
    let rules = try AuthorizationPolicy.query(on: conn).all().wait()
    let inMemoryAuthorizationPolicy = try app.make(InMemoryAuthorizationPolicy.self)
    for rule in rules {
        let conditionValues = try rule.conditionValues.query(on: conn).all().wait()
        try inMemoryAuthorizationPolicy.addToInMemoryCollection(authPolicy: rule, conditionValues: conditionValues)
    }

}
