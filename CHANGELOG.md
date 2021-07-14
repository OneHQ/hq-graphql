# Changelog

### Breaking changes

### Deprecations

### New features

### Bug fixes

# 2.2.3 (21 July 2021)

### New features

- Root queries support field filters

```graphql
query {
  users(filters: [{ field: username, operation: LIKE, value: "gmail.com" }]) {
    id
    username
  }
}
```

# 2.2.2 (12 February 2021)

### Bug fixes

- UUID scalar supports nil input. This is related to a change introduced in graphql-ruby v1.10 in which `.coerce_input` is called on nil values.

# 2.2.1 (04 February 2021)

### Bug fixes

- Fixed a problem with `::HQ::GraphQL::Comparator` not working correctly when comparing schema definitions

# 2.2.0 (27 January 2021)

### Breaking changes

- Removed ::HQ::GraphQL::Types::Object. Use ::GraphQL::Types::JSON.
- Removed ::HQ::GraphQL::Schema::Enum. Use ::GraphQL::Schema::Enum.
- Removed ::HQ::GraphQL::Schema::InputObject. Use ::GraphQL::Schema::InputObject.
- Removed ::HQ::GraphQL::Schema::Mutation. Use ::GraphQL::Schema::Mutation.
- Removed ::HQ::GraphQL::Schema::Object. Use ::GraphQL::Schema::Object.
- Removed ::HQ::GraphQL::Schema. Use ::GraphQL::Schema.

### New features

- Supports graphql-ruby v1.12 and the ::GraphQL::Execution::Interpreter
