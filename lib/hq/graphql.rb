# typed: true
# frozen_string_literal: true

require "rails"
require "graphql"

module HQ
  module GraphQL
    def self.config
      @config ||= ::ActiveSupport::OrderedOptions.new
    end

    def self.configure(&block)
      config.instance_eval(&block)
    end

    def self.default_scope(scope, context)
      config.default_scope&.call(scope, context) || scope
    end

    def self.reset!
      @root_queries = nil
      @types = nil
      ::HQ::GraphQL::Inputs.reset!
      ::HQ::GraphQL::Types.reset!
    end

    def self.root_queries
      @root_queries ||= Set.new
    end

    def self.types
      @types ||= Set.new
    end
  end
end

require "hq/graphql/active_record_extensions"
require "hq/graphql/scalars"

require "hq/graphql/inputs"
require "hq/graphql/input_object"
require "hq/graphql/mutation"
require "hq/graphql/object"
require "hq/graphql/resource"
require "hq/graphql/root_mutation"
require "hq/graphql/root_query"
require "hq/graphql/types"
require "hq/graphql/engine"
