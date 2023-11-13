# ABACAuthorizationWeb

This is a Demo for the attribute based access control authorization system for Swift Vapor Framework.
The demo uses Postgres, Fluent and Redis. Using PostgreSQL and Redis is not mandatory. You can use other Fluent compatible databases and any caching system you like. Docker and the project's `docker-compose.yml` file will help you setup the environment via `docker-compose up -d`.

You don't have to structure your own project like this to utilize the ABACAuthorization package. You can use it for your separate API and separate backend projects as well as your all-in-one project generated out of the default vapor web template.
This demo-project (brought together under one hood out of two projects - api and backend) shows how a separate API and backend approach could work.
Detailed instructions how to use ABACAuthorization package can be found in the package's README file.
Http Port can be set via `HTTP_PORT` Environment variable, if not set, it defaults to 8080.

> IMPORTANT: At the beginning, the most routes will throw a 403: Forbidden. This is expected, as the default `Auth Policies` are only providing minimal access (see Auth Policies section). Not all Frontend route handlers are implemented like in `TodoController`, this leads to some of the forms not doing anything. However the API route handlers should be implemented and these routes can be tested via a REST client.  


## Login
A default admin user will be created on first start.
username: `webmaster@foo.com`
and the random generated password from console.
> CAUTION: The password will be generated only on a first migration/ seeding of the admin user. See `AdminUserMigration.swift` file in User -> Models for more Info.


## Background info
`ABACMiddleware` is used for securing the API.
For backend services where sessions are used, you need e.g. a `UserAuthSessionsMiddleware`. It's basically a simple AuthSessionsMiddleware + RedirectMiddleware with a little bit of logic for access tokens. 
That means if you access the api directly via a rest, iOS etc. clients, you don't need a `UserAuthSessionsMiddleware`. You also don't need the policy creation GUI etc. if you examine the `ABACAuthorizationPolicyController` you will find a bulk api endpoint which you can use, OR you can feed the database directly OR build your own policy creation GUI etc.
Models with the `...Model` suffix are pure Vapor models and reference types. There can be Data-Transfer-Objects, these are structs, value types, and are used for transferring data between the API and clients. This DTO's can be shared across projects (e.g. Vapor API and iOS client) using a separate swift package.
For example here `UserModel` and `User` or `RoleModel` and `Role`.

A big benefit of the ABACAuthorizationPolicy, you don't need to restart the api/service after adding or modifying policies. It's runtime configurable.

## Auth Policies
1. Take a look at the default `Auth Policies`. Only the policies you see in here, allows actions on the resource. Everything else will throw a 403: Forbidden error.
2. Therefore a `read auth policies` and `read roles` will be created by default. If you want to be able to `read` - `Todo's` or `Users` simply create the specific policy. 
3. You can't delete or update a policy? Do you have a policy which allows you to do that? 


## ABACConditions
Conditions (Attributes) are not mandatory and can be neglected if not needed. If needed they can be created on all "cached" values. That means, everything in `AccessData.UserData` can be used.

Starting from within `UserData` Model, specify a path using dot notation. 
Condition examples: 
- `user.name`, 
- `roles.0.name`

So you could build a policy with a condition like: 
- Operation on type `string`
- Operation itself `==`
- Left hand side is a `reference` to `user.name`
- Right hand side is a `value` for example `foo`

Pretty straight forward, that would only grant access if the users name is equal to `foo`.
> The key has to be unique for that specific authorization policy e.g. key1, key2, ... .


## Advice
See `UserController` routes -> Internal vs External routes. All the internal routes make use of ABACAuthorization where you need such a system. External routes like all "MyUser" routes, don't need such an authorization as a user is allowed to change his own data.



## Horizontal scaling

> This approach is mostly made with Kubernetes' headless service in mind, you can modify your  `_recreateAllInMemoryPolicies` route handler to fit your needs. For example injecting an array with all api instances etc.

To achieve a fast decision making process for the evaluation if a request should be permitted or denied, all ABAC policies are stored in memory. This approach leads to some extra work to keep all instances, their in-memory policies, in sync.   
See the `ABACAuthorizationPolicyController`, there is a route handler called `_recreateAllInMemoryPolicies`, which should be requested with an `address` url query, pointing to the headless service.
Without the `address` url query an api instance will simply recreate all its in memory policies with the data from the configured database.
In a dynamic environment like a Kubernetes cluster, where your api instances can be re-created and deployed on different nodes at any time (IP addresses can change), you need a mechanism to address each api instance. Therefore an `nslookup` on a Kubernetes headless service, gives you all ip addresses of your currently running api instances.
To execute such a lookup using swift, we make us of OpenKitten's DNSClient (https://github.com/OpenKitten/NioDNS.git). Afterwards, the route controller requests itself recursively while iterating over the array with api addresses but the request for each instances `_recreateAllInMemoryPolicies` route does NOT contain an `address` url query, so each api instance recreates its in-memory policies.
As this is a protected route, the SystemBot user has to be logged in and use its token to send the update request to all instances.




## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
