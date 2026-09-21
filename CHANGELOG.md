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

# [Unreleased]

### Added

- `config.nullable_associations` emits association fields on OUTPUT types as nullable. Off by default, so the gem behaves exactly as before for every consumer that has not opted in. A host app whose authorization can deny a record needs it: the denial returns `nil`, and at a non-null position that `nil` propagates to the nearest nullable ancestor and takes the whole payload with it, turning a hidden relationship into a failed query. One flag covers all three association shapes — `has_many`, `has_one` and `belongs_to`. Only the OUTER wrapper is relaxed (`[T!]!` -> `[T!]`, `T!` -> `T`); list elements stay non-null, because a per-record denial must shorten the collection through `config.default_scope`, not leave a hole in it. Input types are untouched: presence validation is a legitimate constraint on what a client may send, and is unrelated to what the server is willing to return.
- `config.authorize_association_target` hands the association's TARGET class to `config.authorize_field`, instead of the association's owner. Off by default. Association fields have always been built with `klass: model_name` -- the owner -- so a host's field-level check was only ever asked "may this user see `Advisor`?" for `advisor.salesManagers`, a question it had necessarily already answered to reach the field. A resource-level denial on `SalesManager` could therefore never fire at the field, and fell through to the per-record object hook, whose only move is nulling individual list ELEMENTS -- illegal against a non-null element type, so the host got `Cannot return null for non-nullable field Advisor.salesManagers` and a nulled list rather than a hidden one. With the flag on, the host is asked the question it can answer ("may this user see `SalesManager`?") once, before resolving, and a denial nulls the field itself -- which `config.nullable_associations` has made legal. The owner is still passed as the `parent_klass`, so hosts that scope restrictions per parent (`Advisor -> SalesManager` distinct from `Opportunity -> SalesManager`) get that for free. Per-record denials are unaffected and remain the object hook's job.
- A mutation denied by `config.authorize` now says so. `ready?` returned a bare `false`, which stops execution and resolves the field to `null` with NO entry in `errors` -- a client got a 200, a null payload, and no way to tell "you may not do this" apart from "nothing happened", which a form reads as a successful save. It now returns graphql-ruby's `[false, early_return]`, so the refusal arrives in the payload's own `errors` (`{ "base" => ["You are not allowed to update advisors"] }`), the same shape and wording a denied nested attribute produces. Callers that only checked for a null payload keep working; callers that read `errors` start seeing the reason.
- `config.nullable_root_collections` emits ROOT collection fields as nullable. Off by default. Same reasoning as `nullable_associations`, one level up: a root collection is declared `AdvisorConnection!`, so a host that denies the field has nowhere to put the denial and the `nil` propagates to `data` -- one restricted resource blanks the entire response, however little of the page depended on it. Nullable rather than an EMPTY collection on purpose: `[]` asserts "there are none", which is a different fact from "these are not yours to see", and a client that cannot tell them apart will state the wrong one. It also keeps one answer to one question -- associations already say `null` for a denial, so root collections saying `[]` would mean the same denial reads differently depending on where the field sits. Works regardless of how a resolver builds its scope, so a custom `def_root` that deliberately bypasses `default_scope` is still safe.
- `config.authorize_nested_attributes` authorizes the records a mutation reaches through NESTED ATTRIBUTES. Inert until the host sets it, so nothing changes for a consumer that has not opted in. A generated mutation only ever authorized its own model and action -- `ready?` asks "may I update Advisor?" and nothing else -- so any association writable through that mutation bypassed its own resource authorization: a user forbidden to create a `SalesManager` could still create one by sending it inside an `AdvisorUpdate`, because the payload was never inspected. The walk infers the action for each row the way the record itself would be treated: `_destroy`, or this gem's `X` marker (whose `X=` writer calls `mark_for_destruction`), means destroy; a primary key means update; neither means create. Checking the markers BEFORE the primary key matters -- a row removing itself still carries its id, so reading the id first would call it an update and let a delete restriction through, recurses to every depth the inputs allow, and passes the owner as the parent so restrictions scoped per parent resolve as they do for reads. A violation REJECTS the mutation, writing nothing -- silently dropping unauthorized attributes would apply an edit in part with no feedback. Refusals come back in `errors`, keyed by the input field the client sent (`salesManagers`) so a caller can map them back to what it submitted, and worded through `model_name.human` ("You are not allowed to create sales managers") so an app can override them in its locale.

# [5.0.4] 2026-09-03

### Changed

- The `search_options` resolver (from `auto_register_search_options!`) now passes `current_user: context[:current_user]` and `current_application: context[:current_application]` through to the model's `.search_options(query, options)` call, alongside the existing `organization_id`/`with`. Additive — existing `.search_options` implementations that don't read those keys are unaffected. Lets a model's `search_options` call into `HasHelpers::Search.search` (which needs a real user/application), instead of being limited to plain ActiveRecord queries.
- The `search_options` resolver no longer applies a default limit of 15 when the caller doesn't pass `with: { limit: }`. `default_limit:` now defaults to `nil`, so results are unbounded unless the caller passes `limit`, or the resource explicitly opts into a cap via `search_options(default_limit: N)`.

### Fixed

- Pinned the `json` dependency to `< 3`. `graphql` (`~> 1.13`) calls `JSON.generate`/`.parse` with the legacy `quirks_mode:` option, which `json` 3.0 removed, so a fresh `bundle install` (this gem doesn't commit a `Gemfile.lock`) could resolve `json` 3.x and raise `ArgumentError: unknown keyword: quirks_mode` from `Schema#to_definition`/`#multiplex`.

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
