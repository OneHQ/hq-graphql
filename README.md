# HQ::GraphQL

OneHQ GraphQL interface to [Ruby Graphql](https://github.com/rmosolgo/graphql-ruby).

[![CircleCI](https://img.shields.io/circleci/project/github/OneHQ/hq-graphql.svg)](https://circleci.com/gh/OneHQ/hq-graphql/tree/master)
[![GitHub tag](https://img.shields.io/github/tag/OneHQ/hq-graphql.svg)](https://github.com/OneHQ/hq-graphql)

## Configuration

### Default Scope
Define a global default scope.

```ruby
::HQ::GraphQL.config do |config|
  config.default_scope = ->(scope, context) do
    scope.where(organization_id: context[:organization_id])
  end
end
```

## GraphQL Resource
Connect to ActiveRecord to auto generate queries and mutations.

### Queries
Include `::HQ::GraphQL::Resource` and set `self.model_name` to start using queries.
Fields will be created for all active record columns. Association fields will be created if the association
is also a GraphQL Resource.

```ruby
class AdvisorResource
  include ::HQ::GraphQL::Resource

  # ActiveRecord Model Name
  self.model_name = "Advisor"
end
```

#### Customize
```ruby
class AdvisorResource
  include ::HQ::GraphQL::Resource
  self.model_name = "Advisor"

  # Turn off fields for active record associations
  query attributes: true, associations: false do
    # Create field for addresses
    add_association :addresses

    # add a custom field
    field :custom_field, String, null: false

    def custom_field
      "Fizz"
    end
  end
end
```

### Mutations
Mutations will not be created by default. Add `mutations` to a resource to build mutations for create, update, and destroy.

```ruby
class AdvisorResource
  include ::HQ::GraphQL::Resource
  self.model_name = "Advisor"

  # Builds the following mutations:
  #   createAdvisor
  #   updateAdvisor
  #   destroyAdvisor
  mutations create: true, update: true, destroy: true

  # Turn off fields for active record associations
  inputs attributes: true, associations: false do
    # Create input argument for addresses
    add_association :addresses
  end
end
```

### Root Mutations
Add mutations to your schema

```ruby
class RootMutation < ::HQ::GraphQL::RootMutation; end

class Schema < ::GraphQL::Schema
  mutation(RootMutation)
end
```

### Default Root Queries
Create a root query:
```ruby
class AdvisorResource
  include ::HQ::GraphQL::Resource
  self.model_name = "Advisor"

  root_query
end

class RootQuery < ::HQ::GraphQL::RootQuery; end

class Schema < ::GraphQL::Schema
  mutation(RootQuery)
end
```

### Custom Root Queries
```ruby
class AdvisorResource
  include ::HQ::GraphQL::Resource
  self.model_name = "Advisor"

  def_root :advisors, is_array: true, null: false do
    argument :active, ::GraphQL::Types::Boolean, required: false

    def resolve(active: nil)
      scope = Advisor.all

      if active
        scope = scope.where(active: true)
      end
    end
  end
end
```

## Create a new ::HQ::GraphQL::Object
```ruby
class AdvisorType < ::HQ::GraphQL::Object
  # Supports graphql-ruby functionality
  field :id, Int, null: false

  # Lazy Loading
  # Useful for loading data from the database to generate a schema
  lazy_load do
    load_data_from_db.each do |name|
      field name, String, null: false
    end
  end

  # Attach the GraphQL object to an ActiveRecord Model
  # First argument is the string form of your ActiveRecord model.
  #
  # attributes:
  #  Set it to false if you don't want to auto-include your model's attributes.
  #  Defaults to true.
  #
  # associations:
  #  Set it to false if you don't want to auto-include your model's associations.
  #  Defaults to true.
  with_model "Advisor", attributes: true, associations: false

  # Remove attributes that were included by `with_model`
  remove_attrs :id, :created_at, :updated_at

  # Remove associations that were included by `with_model`
  remove_associations :organization, :created_by
end
```
