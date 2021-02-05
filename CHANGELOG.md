# Changelog

### Breaking changes

### Deprecations

### New features

### Bug fixes

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
