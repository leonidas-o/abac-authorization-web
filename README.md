# ABACAuthorization

This is a Demo for the attribute based access control authorization system for the Swift Vapor Framework.
The demo uses Postgres, FluentPostgresSQL and Redis. Using docker and the projects `docker-compose.yml` file you can setup the environment with `docker-compose up -d`.

## Background info
`ABACMiddleware` is used for securing the API.
For backend services where sessions are used, you need e.g. a `UserAuthSessionsMiddleware`. It's basically a simple AuthSessionsMiddleware + RedirectMiddleware with a little bit of logic for access tokens. 
That means if you access the api directly via a rest, ios etc. clients, you don't need a `UserAuthSessionsMiddleware`. You also don't need the policy creation gui etc. if you examine the `AuthorizationPolicyController` you will find a bulk api endpoint, or feed the database directly or build your own policy creation gui etc.
Models prefixed with `API...` are used for JSON De-/Encoding, so this models are used for transfering data between the API and clients. These are intended to be a public/shareable versions of a model. For example `User.Public` and if there would be an `APIUser` model, they would be identical.
You don't need to restart the api/service after adding or modyfing policies. It's runtime configurable as the ABACAuthorization Package makes use of fluents lifecycle methods.

## Conditions
Conditions can be made on all "cached" values. That means, everything in `AccessData.UserData` can be used.

Starting from within `UserData` Model, specify a path using dot notation. condition examples: 
- `user.name`, 
- `roles.0.name`

So you could build a policy with a condition e.g. 
- Operation on `string`
- Operation itself `==`
- Left hand side is a `reference` to `user.name`
- Right hand side is a `value` like `foo`

Pretty straight forward, that would only grant access if the users name is equal to `foo`. 


## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
