# HQ_GRAPHQL

# Changelog

All notable changes to this project are documented in this file

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Guiding Principles

- Changelogs are for humans, not machines.
- There should be an entry for every single version.
- The same types of changes should be grouped.
- Versions and sections should be linkable.
- The latest version comes first.
- The release date of each version is displayed.
- Mention whether you follow Semantic Versioning.

### Types of changes

- **Added** for new features.
- **Changed** for changes in existing functionality.
- **Deprecated** for soon-to-be removed features.
- **Removed** for now removed features.
- **Fixed** for any bug fixes.
- **Security** in case of vulnerabilities.

# [2.2.0] 2021-01-27
### Changed
- Removed ::HQ::GraphQL::Types::Object. Use ::GraphQL::Types::JSON.
- Removed ::HQ::GraphQL::Schema::Enum. Use ::GraphQL::Schema::Enum.
- Removed ::HQ::GraphQL::Schema::InputObject. Use ::GraphQL::Schema::InputObject.
- Removed ::HQ::GraphQL::Schema::Mutation. Use ::GraphQL::Schema::Mutation.
- Removed ::HQ::GraphQL::Schema::Object. Use ::GraphQL::Schema::Object.
- Removed ::HQ::GraphQL::Schema. Use ::GraphQL::Schema.
### Added
- Supports graphql-ruby v1.12 and the ::GraphQL::Execution::Interpreter

# [2.2.1] 2021-02-04
### Fixed
- Fixed a problem with `::HQ::GraphQL::Comparator` not working correctly when comparing schema definitions

# [2.2.2] 2021-02-12
### Fixed
- UUID scalar supports nil input. This is related to a change introduced in graphql-ruby v1.10 in which `.coerce_input` is called on nil values.

# [2.2.3] 2021-07-21
### Added
- Root queries support field filters
```graphql
query {
  users(filters: [{ field: username, operation: LIKE, value: "gmail.com" }]) {
    id
    username
  }
}
```

# [2.2.4] 2021-10-08
### Fixed
- Multiplex queries correctly load dynamic types

# [2.2.5] 2021-11-02
### Fixed
- Date Type issue fixed

# [2.2.6] 2022-02-14
### Fixed
- FilterInput type naming change due to naming collision with resources

# [2.2.6] 2022-09-23
### Added
- List queries with optional pagination based on queries (connection type)
```
query {
  userPagination(filters:[UserQueryFilterInput]! , limit: Int, sortOrder: SortOrder, sortBy: SortBy, first: Int, after: String){
       totalCount
       cursors
       pageInfo{ startCursor  endCursor }
      edges { cursor node{ id name } }
  }
}
```

# [2.3.0] 2022-11-08
### Changed
- All list queries are now pagination based on queries (connection type)

# [2.3.2] 2023-01-13
### Added
- Root queries filters with new filters:
  * Operation IN: field included in array_values
  * OR filter: add isOr: true to pass an OR statement (based on filter order passed)
  * Comparison between columns: using column_value argument

# [2.3.3] 2023-02-03
### Added
- By default, New Queries will be generated if Create Mutation is available. These queries will be useful for forms init. Default values will be based on methods applied using after_initialize callback on model.
```
{
  newAdvisor {
    name
    advisor_status_id
    demographic {
      id
      ...
    }
  }
}
```

# [2.3.4] 2023-03-06
### Changed
- limit_max is removed from root_query. Now is 250

## [2.3.5] 2024-12-06
### Fixed
- New Queries will execute validations instead of after_initialize callback. Will accept initial parameters before run validations

## [2.3.6] 2024-12-06
### Fixed
- All pagination queries created with root_query, def_root and resolvers will have a 250 limit as default. 

## [2.3.7] 2025-11-27
### Changed
- Changelog file modified for standard
- On the gemspec file, allow to be used for Rails versions between 6.1 and 8.1.1.
