# frozen_string_literal: true

require "rails"
require "graphql"
require "graphql/batch"
require "hq/graphql/field"
require "hq/graphql/config"

module HQ
  module GraphQL
    def self.config
      @config ||= ::HQ::GraphQL::Config.new
    end

    def self.configure(&block)
      config.instance_eval(&block)
    end

    def self.authorized?(action, object, context)
      !config.authorize || config.authorize.call(action, object, context)
    end

    def self.authorize_field(action, field, object, context)
      !config.authorize_field || config.authorize_field.call(action, field, object, context)
    end

    def self.default_scope(scope, context)
      config.default_scope.call(scope, context)
    end

    def self.extract_class(klass)
      config.extract_class.call(klass)
    end

    def self.lookup_resource(klass)
      [klass, klass.base_class, klass.superclass].lazy.map do |k|
        config.resource_lookup.call(k) || resources.detect { |r| r.model_klass == k }
      end.reject(&:nil?).first
    end

    def self.use_experimental_associations?
      !!config.use_experimental_associations
    end

    def self.reset!
      @root_queries = nil
      @enums = nil
      @resources = nil
      ::HQ::GraphQL::Inputs.reset!
      ::HQ::GraphQL::Types.reset!
    end

    def self.root_queries
      @root_queries ||= Set.new
    end

    def self.enums
      @enums ||= Set.new
    end

    def self.resources
      @resources ||= Set.new
    end
  end
end

require "hq/graphql/active_record_extensions"
require "hq/graphql/association_loader"
require "hq/graphql/scalars"
require "hq/graphql/comparator"
require "hq/graphql/enum"
require "hq/graphql/inputs"
require "hq/graphql/input_object"
require "hq/graphql/mutation"
require "hq/graphql/object"
require "hq/graphql/paginated_association_loader"
require "hq/graphql/resource"
require "hq/graphql/root_mutation"
require "hq/graphql/root_query"
require "hq/graphql/schema"
require "hq/graphql/types"
require "hq/graphql/engine"
