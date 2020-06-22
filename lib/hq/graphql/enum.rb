# frozen_string_literal: true

require "hq/graphql/types"

module HQ::GraphQL
  class Enum < ::GraphQL::Schema::Enum
    ## Auto generate enums from the database using ActiveRecord
    #  This comes in handy when we have constants that we want represented as enums.
    #
    # == Example
    #   Let's assume we're saving data into a user types table
    #     # select * from user_types;
    #      id |    name
    #     --- +-------------
    #      1  | Admin
    #      2  | Support User
    #     (2 rows)
    #
    #  ```ruby
    #    class Enums::UserType < ::HQ::GraphQL::Enum
    #      with_model
    #    end
    #  ```
    #
    #  Creates the following enum:
    #  ```graphql
    #    enum UserType {
    #      Admin
    #      SupportUser
    #    }
    #  ```
    def self.with_model(
      klass = default_model_name.safe_constantize,
      prefix: nil,
      register: true,
      scope: nil,
      value_method: :name
    )
      raise ArgumentError.new(<<~ERROR) if !klass
        `::HQ::GraphQL::Enum.with_model {...}' had trouble automatically inferring the class name.
        Avoid this by manually passing in the class name: `::HQ::GraphQL::Enum.with_model(#{default_model_name}) {...}`
      ERROR

      if register
        ::HQ::GraphQL.enums << klass
        ::HQ::GraphQL::Types.register(klass, self)
      end

      lazy_load do
        records = scope ? klass.instance_exec(&scope) : klass.all
        records.each do |record|
          value "#{prefix}#{record.send(value_method).delete(" ")}", value: record
        end
      end
    end

    def self.lazy_load(&block)
      @lazy_load ||= []
      @lazy_load << block if block
      @lazy_load
    end

    def self.lazy_load!
      lazy_load.map(&:call)
      @lazy_load = []
    end

    def self.to_graphql
      lazy_load!
      super
    end

    def self.default_model_name
      to_s.sub(/^((::)?\w+)::/, "")
    end
  end
end
