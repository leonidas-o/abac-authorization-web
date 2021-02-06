import Vapor
import ABACAuthorization
import FluentSQL

struct Prepare: LifecycleHandler {
    
    func didBoot(_ app: Application) throws {
        
        // MARK: ABACAuthorization
        
        if let sql = app.db as? SQLDatabase {
            let query = SQLQueryString("SELECT EXISTS (SELECT FROM pg_tables where tablename  = '" + ABACAuthorizationPolicyModel.schema + "');")
            let abacPolicySchema = try sql.raw(query).first(decoding: [String:Bool].self).wait()
            if abacPolicySchema?.first?.value == true {
                let policies = try app.abacAuthorizationRepo.getAllWithConditions().wait()
                for policy in policies {
                    try app.abacAuthorizationPolicyService.addToInMemoryCollection(policy: policy, conditions: policy.conditions)
                }
            }
        }
    }
}
