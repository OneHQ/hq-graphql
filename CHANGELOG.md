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

# [5.0.4] 2026-09-03

### Changed

- The `search_options` resolver (from `auto_register_search_options!`) now passes `current_user: context[:current_user]` and `current_application: context[:current_application]` through to the model's `.search_options(query, options)` call, alongside the existing `organization_id`/`with`. Additive — existing `.search_options` implementations that don't read those keys are unaffected. Lets a model's `search_options` call into `HasHelpers::Search.search` (which needs a real user/application), instead of being limited to plain ActiveRecord queries.
- The `search_options` resolver no longer applies a default limit of 15 when the caller doesn't pass `with: { limit: }`. `default_limit:` now defaults to `nil`, so results are unbounded unless the caller passes `limit`, or the resource explicitly opts into a cap via `search_options(default_limit: N)`.

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

- UUID scalar supports nil input. This is related to a change introduced in graphql-ruby v1.10 in which `.coerce_input`
  is called on nil values.

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

- By default, New Queries will be generated if Create Mutation is available. These queries will be useful for forms
  init. Default values will be based on methods applied using after_initialize callback on model.
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

- New Queries will execute validations instead of after_initialize callback. Will accept initial parameters before run
  validations

## [2.3.6] 2024-12-06

### Fixed

- All pagination queries created with root_query, def_root and resolvers will have a 250 limit as default.

## [5.0.0] 2025-12-01

### Changed

- Changelog file modified for standard
- Ruby version upgraded to 3.4.4
- In the gemspec file, allow to be used for Rails versions between 6.1 and 8.1.1.

## [5.0.2] 2026-08-03

### Changed

- Subclasses are included in types where the main class is present.

## [5.0.3] 2026-08-18

### Added

- `Resource.search_options`, a macro that registers a dedicated root query field (e.g. `levelSearchOptions`)
  backed by the resource's model `.search_options`/`.search_options_groups`. The returned type defaults to
  `HQ::GraphQL.config.default_search_type`, or can be overridden per-resource with `type:`.
- `HQ::GraphQL.auto_register_search_options!`, which calls `search_options` for every resource whose model
  already defines `.search_options`, so it rarely needs to be called explicitly per resource. Stateless and
  safe to call repeatedly -- `Resource#search_options` is idempotent per resource via
  `@search_options_registered`, set only once its field is actually built. Not wired to any hq-graphql
  lifecycle hook: when a consuming app's boot process finalizes `root_queries` into real schema fields (e.g.
  by explicitly building/dumping the schema during initialization, ahead of `HQ::GraphQL::RootQuery`'s own
  lazy field-building) varies per app, so the app calls this itself at that point. See e.g. agencieshq's
  `z_graphql_resources_to_reload.rb`.
- `Resource.search_options` now remaps results to an `Owner`-prefixed class by id when one exists for the
  model (e.g. `OwnerLevel` for `Level`), so the owner view is returned instead of the base model instances.
  Order and the applied limit are preserved.
