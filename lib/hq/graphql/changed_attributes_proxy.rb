# frozen_string_literal: true

require "delegate"

module HQ
  module GraphQL
    # Wraps a saved ActiveRecord instance so that GraphQL field resolution returns
    # nil for any column attribute that wasn't part of the last save, while every
    # other method (associations, the primary key, custom resolvers) is delegated
    # to the underlying record untouched. Used by resources with `return_copy: true`
    # so the update mutation only echoes back the attributes that actually changed.
    #
    # This must NOT mutate the underlying record itself (e.g. via define_singleton_method
    # on the real object): associations declared with `inverse_of` make ActiveRecord's
    # Preloader wire a loaded child's belongs_to straight back to whichever object
    # instance was used to trigger the preload, with no extra query. If that instance
    # were the real record with columns nulled out, any other field resolving that
    # association's inverse (even through the regular, non-nullable type) would
    # silently inherit the artificial nils. Delegating instead means associations are
    # always loaded through `__getobj__` (the real record), so Rails' inverse-of
    # caching always points at an untouched object.
    #
    # `is_a?`/`kind_of?`/`class` are overridden because SimpleDelegator doesn't satisfy
    # them by default — association loaders in this gem rely on `record.is_a?(model)`
    # and ActiveRecord's Preloader relies on `record.class` to resolve reflections.
    class ChangedAttributesProxy < SimpleDelegator
      def self.wrap(resource, changed_attributes)
        new(resource, changed_attributes)
      end

      def initialize(resource, changed_attributes)
        super(resource)
        @primary_key = resource.class.primary_key.to_s
        @changed_attributes = changed_attributes.map(&:to_s).to_set
        @column_names = resource.class.column_names.to_set
      end

      def class
        __getobj__.class
      end

      def is_a?(klass)
        __getobj__.is_a?(klass)
      end
      alias_method :kind_of?, :is_a?

      def instance_of?(klass)
        __getobj__.instance_of?(klass)
      end

      def method_missing(name, *args, &block)
        attr_name = name.to_s
        if attr_name != @primary_key && @column_names.include?(attr_name) && !@changed_attributes.include?(attr_name)
          nil
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        super
      end
    end
  end
end
