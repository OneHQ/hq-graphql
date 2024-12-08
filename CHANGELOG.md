# Changelog

### Breaking changes

### Deprecations

### New features

### Bug fixes

# 2.3.6 (6 December 2024)

### Bug fixes

- All pagination queries created with root_query, def_root and resolvers will have a 250 limit as default. 

# 2.3.5 (14 January 2023)

### Breaking changes

- New Queries will execute validations instead of after_initialize callback. Will accept initial parameters before run validations

# 2.3.4 (6 March 2023)

### Breaking changes

- limit_max is removed from root_query. Now is 250

# 2.3.3 (3 February 2023)

### New features

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

# 2.3.2 (13 January 2023)

### New features

- Root queries filters with new filters:
  Operation IN: field included in array_values
  OR filter: add isOr: true to pass an OR statement (based on filter order passed)
  Comparison between columns: using column_value argument

# 2.3.0 (8 November 2022)

### Breaking changes

- All list queries are now pagination based on queries (connection type)

# 2.2.6 (23 September 2022)

### New features

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



# 2.2.6 (14 February 2022)

### Bug fixes

- FilterInput type naming change due to naming collision with resources

# 2.2.5 (2 November 2021)

### Bug fixes

- Date Type issue fixed

# 2.2.4 (8 October 2021)

### Bug fixes

- Multiplex queries correctly load dynamic types

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
