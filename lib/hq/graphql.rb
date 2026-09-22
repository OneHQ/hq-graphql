# frozen_string_literal: true

require "rails"
require "active_model"
require "graphql"
require "graphql/batch"
require "hq/graphql/field"
require "hq/graphql/config"
require "hq/graphql/authorization_message"
require "hq/graphql/nested_authorization"

module HQ
  module GraphQL
    class << self
      delegate :default_object_class, to: :config
    end

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

    # Authorizes one record reached through a mutation's nested attributes.
    # `klass` is the association's class, `parent_klass` its owner. Inert until
    # the host sets `config.authorize_nested_attributes`; see
    # `HQ::GraphQL::NestedAuthorization`.
    def self.authorize_nested_attributes(action, klass, parent_klass, context)
      !config.authorize_nested_attributes ||
        config.authorize_nested_attributes.call(action, klass, parent_klass, context)
    end

    def self.default_scope(scope, context)
      config.default_scope.call(scope, context)
    end

    def self.extract_class(klass)
      config.extract_class.call(klass)
    end

    def self.excluded_inputs
      config.excluded_inputs || []
    end

    def self.lookup_resource(klass)
      [klass, klass.base_class, klass.superclass].lazy.map do |k|
        config.resource_lookup.call(k) || resources.detect { |r| r.model_klass == k }
      end.reject(&:nil?).first
    end

    def self.use_experimental_associations?
      !!config.use_experimental_associations
    end

    # When enabled, association fields on OUTPUT types are emitted nullable.
    # A host app whose authorization can deny a record needs this: a denial
    # returns nil, and at a non-null position that nil propagates up and takes
    # the whole payload with it. Only the OUTER wrapper is relaxed --
    # `[T!]!` becomes `[T!]` and `T!` becomes `T`; list ELEMENTS stay non-null,
    # because a per-record denial must shorten the collection (via
    # `config.default_scope`), never punch a hole in it.
    #
    # Off by default, so the gem behaves exactly as before for every consumer
    # that has not opted in.
    def self.nullable_associations?
      !!config.nullable_associations
    end

    # When enabled, ROOT collection fields are emitted nullable.
    #
    # Same reasoning as `nullable_associations`, one level up. A root collection
    # is declared `AdvisorConnection!`, so a host that denies the field has
    # nowhere to put the denial: the nil propagates to `data` and the whole
    # response is lost, however little of the page depended on it.
    #
    # Nullable, rather than an empty collection, on purpose: `[]` says "there
    # are none", which is a different fact from "these are not yours to see",
    # and a client that cannot tell them apart will state the wrong one. This
    # keeps the same distinction the association flag draws -- null for denied,
    # empty for genuinely nothing -- so a field means the same thing wherever it
    # sits.
    #
    # Off by default.
    def self.nullable_root_collections?
      !!config.nullable_root_collections
    end

    # Which class an association field hands to `config.authorize_field`.
    #
    # Off: the association's OWNER, which the host has necessarily already
    # authorized to have reached the field -- so a resource-level denial on the
    # association's own class can never fire here. It falls through to the
    # per-record object hook instead, whose only move is nulling individual list
    # elements; against a non-null element type that is an error, not a hidden
    # field.
    #
    # On: the association's TARGET class, so the host is asked the question it
    # can actually answer -- "may this user see SalesManager?" -- once, before
    # resolving. A denial then nulls the field itself, which `nullable_associations`
    # has made legal. Per-record denials are unaffected and still belong to the
    # object hook (or `config.default_scope`).
    def self.authorize_association_target?
      !!config.authorize_association_target
    end

    def self.reset!
      @lazy_load_classes = nil
      @root_queries = nil
      @enums = nil
      @resources = nil
      ::HQ::GraphQL::Inputs.reset!
      ::HQ::GraphQL::Types.reset!
    end

    def self.load_types!
      lazy_load_classes.pop.lazy_load! while lazy_load_classes.length > 0
    end

    # Registers the `search_options` root field for any resource whose model_klass
    # already defines `.search_options`, so resources don't need to call it explicitly.
    # Not wired to any hq-graphql lifecycle hook -- consuming apps call this themselves
    # at whatever point their own boot process finalizes root_queries into real schema
    # fields (that point varies per app; see e.g. agencieshq's
    # z_graphql_resources_to_reload.rb). Stateless and safe to call repeatedly:
    # Resource#search_options is idempotent per resource via @search_options_registered.
    def self.auto_register_search_options!
      resources.each do |resource|
        next unless resource.model_klass.respond_to?(:search_options)
        resource.send(:search_options)
      end
    end

    def self.lazy_load(klass)
      lazy_load_classes << klass unless lazy_load_classes.include?(klass)
    end

    def self.lazy_load_classes
      @lazy_load_classes ||= []
    end

    def self.root_queries
      @root_queries ||= []
    end

    def self.enums
      @enums ||= []
    end

    def self.resources
      @resources ||= []
    end
  end
end

require "hq/graphql/association_loader"
require "hq/graphql/scalars"
require "hq/graphql/comparator"
require "hq/graphql/ext"
require "hq/graphql/inputs"
require "hq/graphql/paginated_association_loader"
require "hq/graphql/record_loader"
require "hq/graphql/resource"
require "hq/graphql/root_mutation"
require "hq/graphql/root_query"
require "hq/graphql/types"
require "hq/graphql/engine"
