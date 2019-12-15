import Vapor
import FluentPostgreSQL
import Foundation
import ABACAuthorization

final class AuthorizationPolicyPostgreSQLStore: AuthorizationPolicyPersistenceStore {
    
    let db: PostgreSQLDatabase.ConnectionPool
    
    init(_ db: PostgreSQLDatabase.ConnectionPool) {
        self.db = db
    }
    
    
    
    // MARK: - AuthorizationPolicy
    
    func save(_ authPolicy: AuthorizationPolicy) -> Future<APIAuthorizationPolicyResponse> {
        return db.withConnection{ conn in
            return authPolicy.save(on: conn).flatMap{ savedAuthPolicy in
                return try savedAuthPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                    guard let id = savedAuthPolicy.id else { throw Abort(.internalServerError) }
                    let apiAuthPolicy = APIAuthorizationPolicyWithConditions(
                        id: id,
                        roleName: savedAuthPolicy.roleName,
                        actionOnResourceKey: savedAuthPolicy.actionOnResourceKey,
                        actionOnResourceValue: savedAuthPolicy.actionOnResourceValue,
                        conditionValues: conditionValues)
                    return APIAuthorizationPolicyResponse(type: .one, source: [apiAuthPolicy])
                }
            }
        }
    }

    func saveBulk(_ authPolicies: [AuthorizationPolicy]) -> Future<APIAuthorizationPolicyResponse> {
        return db.withConnection{ conn in
            
            var policySaveResults: [Future<AuthorizationPolicy>] = []
            for policy in authPolicies {
                policySaveResults.append(policy.save(on: conn))
            }
            return policySaveResults.flatten(on: conn).flatMap{ savedAuthPolicies in
                
                var apiAuthPolicyResponseSourceResult: [Future<APIAuthorizationPolicyWithConditions>] = []
                for savedPolicy in savedAuthPolicies {
                    
                    let apiAuthPolicy = try savedPolicy.conditionValues.query(on: conn).all().map(to: APIAuthorizationPolicyWithConditions.self){ conditionValues in
                        guard let id = savedPolicy.id else { throw Abort(.internalServerError) }
                        return APIAuthorizationPolicyWithConditions(
                            id: id,
                            roleName: savedPolicy.roleName,
                            actionOnResourceKey: savedPolicy.actionOnResourceKey,
                            actionOnResourceValue: savedPolicy.actionOnResourceValue,
                            conditionValues: conditionValues)
                    }
                    apiAuthPolicyResponseSourceResult.append(apiAuthPolicy)
                }
                return apiAuthPolicyResponseSourceResult.flatten(on: conn).map{ apiAuthPolicies in
                    return APIAuthorizationPolicyResponse(type: .partial, source: apiAuthPolicies)
                }
            }
        }
    }


    
    func getAll() -> Future<APIAuthorizationPolicyResponse> {
        return db.withConnection{ conn in
            return conn.raw("""
            SELECT "AuthorizationPolicy".*, ARRAY_REMOVE(ARRAY_AGG(TO_JSONB("ConditionValueDB".*)), NULL) AS "conditionValues" FROM "AuthorizationPolicy"
            LEFT JOIN "ConditionValueDB" ON "AuthorizationPolicy"."id" = "ConditionValueDB"."authorizationPolicyID"
            GROUP BY "AuthorizationPolicy"."id";
            """).all(decoding: AuthPolicyConditionValuesAgg.self).map{ aggCollection in
                let apiAuthPolicyCollection = try aggCollection.map{ agg -> APIAuthorizationPolicyWithConditions in
                    guard let id = agg.id else { throw Abort(.internalServerError) }
                    return APIAuthorizationPolicyWithConditions(
                        id: id,
                        roleName: agg.roleName,
                        actionOnResourceKey: agg.actionOnResourceKey,
                        actionOnResourceValue: agg.actionOnResourceValue,
                        conditionValues: agg.conditionValues)
                }
                return APIAuthorizationPolicyResponse(type: .full, source: apiAuthPolicyCollection)
            }
        }
    }
    
    
    func get(_ authPolicy: AuthorizationPolicy) -> Future<APIAuthorizationPolicyResponse> {
        return db.withConnection{ conn in
            return try authPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                guard let id = authPolicy.id else { throw Abort(.internalServerError) }
                let apiAuthPolicy = APIAuthorizationPolicyWithConditions(
                    id: id,
                    roleName: authPolicy.roleName,
                    actionOnResourceKey: authPolicy.actionOnResourceKey,
                    actionOnResourceValue: authPolicy.actionOnResourceValue,
                    conditionValues: conditionValues)
                return APIAuthorizationPolicyResponse(type: .one, source: [apiAuthPolicy])
            }
        }
    }
    
    
    func update(_ authPolicy: AuthorizationPolicy, to updatedAuthPolicy: AuthorizationPolicy) -> Future<APIAuthorizationPolicyResponse> {
        return db.withConnection{ conn in
            
            authPolicy.roleName = updatedAuthPolicy.roleName
            authPolicy.actionOnResourceKey = updatedAuthPolicy.actionOnResourceKey
            authPolicy.actionOnResourceValue = updatedAuthPolicy.actionOnResourceValue
            
            return authPolicy.save(on: conn).flatMap{ savedPolicy in
                return try savedPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                    guard let id = savedPolicy.id else { throw Abort(.internalServerError) }
                    let apiAuthPolicy = APIAuthorizationPolicyWithConditions(
                        id: id,
                        roleName: savedPolicy.roleName,
                        actionOnResourceKey: savedPolicy.actionOnResourceKey,
                        actionOnResourceValue: savedPolicy.actionOnResourceValue,
                        conditionValues: conditionValues)
                    return APIAuthorizationPolicyResponse(type: .one, source: [apiAuthPolicy])
                }
            }
        }
    }
    
    
    func delete(_ authPolicy: AuthorizationPolicy) -> Future<Void> {
        return db.withConnection{ conn in
            return authPolicy.delete(on: conn)
        }
    }
    
    func delete(_ authPolicies: [AuthorizationPolicy]) -> Future<Void> {
        return db.withConnection{ conn in
            var authPolicyDeleteResults: [Future<Void>] = []
            for policy in authPolicies {
                authPolicyDeleteResults.append(policy.delete(on: conn))
            }
            return authPolicyDeleteResults.flatten(on: conn)
        }
    }
    
    func deleteUsingUniqueKey(_ authPolicies: [AuthorizationPolicy]) -> Future<Void> {
        return db.withConnection{ conn in
            var authPolicyDeleteResults: [Future<Void>] = []
            for policy in authPolicies {
                let deletion = AuthorizationPolicy.query(on: conn).filter(\.actionOnResourceKey == policy.actionOnResourceKey).delete()
                authPolicyDeleteResults.append(deletion)
            }
            return authPolicyDeleteResults.flatten(on: conn)
        }
    }
    
    
    // MARK: - ConditionValueDB
    
    func save(_ conditionValueDB: ConditionValueDB) -> Future<APIConditionValueDBResponse> {
        return db.withConnection{ conn in
            conditionValueDB.save(on: conn).map{ conditionValueDB in
                return APIConditionValueDBResponse(type: .one, source: [conditionValueDB])
            }
        }
    }
    
    func update(_ conditionValueDB: ConditionValueDB, to updatedConditionValueDB: ConditionValueDB) -> Future<APIConditionValueDBResponse> {
        return db.withConnection{ conn in
            
            conditionValueDB.key = updatedConditionValueDB.key
            conditionValueDB.type = updatedConditionValueDB.type
            conditionValueDB.operation = updatedConditionValueDB.operation
            conditionValueDB.lhsType = updatedConditionValueDB.lhsType
            conditionValueDB.lhs = updatedConditionValueDB.lhs
            conditionValueDB.rhsType = updatedConditionValueDB.rhsType
            conditionValueDB.rhs = updatedConditionValueDB.rhs
            //conditionValueDB.authorizationPolicyID = updatedConditionValueDB.authorizationPolicyID
            
            return conditionValueDB.save(on: conn).map{ savedConditionValueDB in
                return APIConditionValueDBResponse(type: .one, source: [savedConditionValueDB])
            }
        }
    }
    
    func delete(_ conditionValueDB: ConditionValueDB) -> Future<Void> {
        return db.withConnection{ conn in
            return conditionValueDB.delete(on: conn)
        }
    }
    
    
    
    // MARK: - Relations
    
    func getAllDBConditionValues(of authPolicy: AuthorizationPolicy) -> Future<APIConditionValueDBResponse> {
        return db.withConnection{ conn in
            try authPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                return APIConditionValueDBResponse(type: .full, source: conditionValues)
            }
        }
    }
    
    func getAuthorizationPolicy(for conditionValueDB: ConditionValueDB) -> Future<APIAuthorizationPolicyResponse> {
        return db.withConnection{ conn in
            return conditionValueDB.authorizationPolicy.get(on: conn).flatMap{ authPolicy in
                return try authPolicy.conditionValues.query(on: conn).all().map{ conditionValues in
                    guard let id = authPolicy.id else { throw Abort(.internalServerError) }
                    let apiAuthPolicy = APIAuthorizationPolicyWithConditions(
                        id: id,
                        roleName: authPolicy.roleName,
                        actionOnResourceKey: authPolicy.actionOnResourceKey,
                        actionOnResourceValue: authPolicy.actionOnResourceValue,
                        conditionValues: conditionValues)
                    return APIAuthorizationPolicyResponse(type: .one, source: [apiAuthPolicy])
                }
            }
        }
    }
    
}




//MARK: - ServiceType conformance

extension AuthorizationPolicyPostgreSQLStore {
    static let serviceSupports: [Any.Type] = [AuthorizationPolicyPersistenceStore.self]
    
    static func makeService(for worker: Container) throws -> Self {
        return .init(try worker.connectionPool(to: .psql))
    }
}




extension AuthorizationPolicyPostgreSQLStore {
    struct AuthPolicyConditionValuesAgg: Decodable, AuthPolicyDefinition {
        var id: UUID?
        var roleName: String
        var actionOnResourceKey: String
        var actionOnResourceValue: Bool
        var conditionValues: [ConditionValueDB]
    }
}
