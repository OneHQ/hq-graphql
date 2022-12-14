# frozen_string_literal: true

require "hq/graphql/types"

module HQ::GraphQL
  module Ext
    module EnumExtensions
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
      def with_model(
        klass = default_model_name.safe_constantize,
        prefix: nil,
        register: true,
        scope: nil,
        strip: /(^[^_a-zA-Z])|([^_a-zA-Z0-9]*)/,
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
            value "#{prefix}#{record.send(value_method).gsub(strip, "")}", value: record
          end
        end
      end

      def lazy_load(&block)
        @lazy_load ||= []
        if block
          ::HQ::GraphQL.lazy_load(self)
          @lazy_load << block
        end
        @lazy_load
      end

      def lazy_load!
        lazy_load.shift.call while lazy_load.length > 0
        @lazy_load = []
      end

      def default_model_name
        to_s.sub(/^((::)?\w+)::/, "")
      end

      # This override method allow us to keep the suffix `-Type`
      # if we don't specify the `graphql_name`.
      def default_graphql_name
        to_s.split("::").last.sub(/\Z/, "")
      end
    end
  end
end


::GraphQL::Schema::Enum.extend ::HQ::GraphQL::Ext::EnumExtensions
