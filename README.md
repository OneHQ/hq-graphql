# HQ::GraphQL

OneHQ GraphQL interface to [Ruby Graphql](https://github.com/rmosolgo/graphql-ruby).

[![CircleCI](https://img.shields.io/circleci/project/github/OneHQ/hq-graphql.svg)](https://circleci.com/gh/OneHQ/hq-graphql/tree/master)
[![GitHub tag](https://img.shields.io/github/tag/OneHQ/hq-graphql.svg)](https://github.com/OneHQ/hq-graphql)

## Configuration

You can pass configuration options as a block to `::HQ::GraphQL.configure`.

```ruby
# The gem assumes that if your model is called `MyModel`, the corresponding type is `MyModelType`.
# You can override that convention.
# Default is: -> (model_class) { "#{model_class.name.demodulize}Type" }
::HQ::GraphQL.config do |config|
  config.model_to_graphql_type = -> (model_class) { "::CustomNameSpace::#{model_class.name}Type" }
end
```

## Usage

Create a new ::HQ::GraphQL::Object
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
