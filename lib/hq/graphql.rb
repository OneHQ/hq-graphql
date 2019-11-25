# typed: true
# frozen_string_literal: true

require "rails"
require "graphql"
require "graphql/batch"
require "sorbet-runtime"
require "hq/graphql/field"
require "hq/graphql/config"

module HQ
  module GraphQL
    extend T::Sig
    extend T::Generic

    @config = T.let(::HQ::GraphQL::Config.new, ::HQ::GraphQL::Config)

    sig { returns(::HQ::GraphQL::Config) }
    def self.config
      @config
    end

    def self.configure(&block)
      config.instance_eval(&block)
    end

    sig { params(action: T.untyped, object: T.untyped, context: ::GraphQL::Query::Context).returns(T::Boolean) }
    def self.authorized?(action, object, context)
      !config.authorize || T.must(config.authorize).call(action, object, context)
    end

    sig { params(action: T.untyped, field: ::HQ::GraphQL::Field, object: T.untyped, context: ::GraphQL::Query::Context).returns(T::Boolean) }
    def self.authorize_field(action, field, object, context)
      !config.authorize_field || T.must(config.authorize_field).call(action, field, object, context)
    end

    sig { params(scope: T.untyped, context: ::GraphQL::Query::Context).returns(T.untyped) }
    def self.default_scope(scope, context)
      config.default_scope.call(scope, context)
    end

    sig { void }
    def self.reset!
      @root_queries = nil
      @types = nil
      ::HQ::GraphQL::Inputs.reset!
      ::HQ::GraphQL::Types.reset!
    end

    def self.root_queries
      @root_queries ||= Set.new
    end

    # sig { returns(T::Set[::HQ::GraphQL::Resource]) }
    def self.types
      @types ||= Set.new
    end
  end
end

require "hq/graphql/active_record_extensions"
require "hq/graphql/scalars"
require "hq/graphql/comparator"
require "hq/graphql/inputs"
require "hq/graphql/input_object"
require "hq/graphql/loaders"
require "hq/graphql/mutation"
require "hq/graphql/object"
require "hq/graphql/resource"
require "hq/graphql/root_mutation"
require "hq/graphql/root_query"
require "hq/graphql/types"
require "hq/graphql/engine"
