# ABACAuthorization

This is a Demo for the attribute based access control authorization system for Swift Vapor Framework.
The demo uses Postgres, Fluent and Redis. Using docker and the project's `docker-compose.yml` file you can setup the environment with `docker-compose up -d`.

You don't have to structure your own project like this to utilize the ABACAuthorization package. You can use it for your separate API and separate backend projects as well as your all-in-one project generated out of the default vapor web template.
This demo-project (brought together under one hood out of two projects - api and backend) shows how a separate API and backend approach could work.
Detailed instructions how to use ABACAuthorization package can be found in the package's README file.


## Background info
`ABACMiddleware` is used for securing the API.
For backend services where sessions are used, you need e.g. a `UserAuthSessionsMiddleware`. It's basically a simple AuthSessionsMiddleware + RedirectMiddleware with a little bit of logic for access tokens. 
That means if you access the api directly via a rest, ios etc. clients, you don't need a `UserAuthSessionsMiddleware`. You also don't need the policy creation gui etc. if you examine the `ABACAuthorizationPolicyController` you will find a bulk api endpoint which you can use, OR you can feed the database directly OR build your own policy creation gui etc.
Models with the `...Model` suffix are pure Vapor models and reference types. There can be Data-Transfer-Objects, these are structs, value types, and are used for transfering data between the API and clients. This DTO's can be shared across projects (e.g. Vapor API and iOS client) using a seprate swift package.
For example here `UserModel` and `User` or `RoleModel` and `Role`.

A big benefit of the ABACAuthorizationPolicy, you don't need to restart the api/service after adding or modyfing policies. It's runtime configurable.


## ABACConditions
Conditions can be made on all "cached" values. That means, everything in `AccessData.UserData` can be used.

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


## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
