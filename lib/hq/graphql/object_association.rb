# frozen_string_literal: true

module HQ
  module GraphQL
    module ObjectAssociation
      def reflect_on_association(association)
        resource_reflections[association.to_s]&.reflection(model_klass)
      end

      def update(name, &block)
        resource_reflections[name.to_s] = UpdatedReflection.new(name, block)
      end

      def belongs_to(name, scope = nil, **options, &block)
        add_reflection(name, scope, options, :belongs_to, block)
      end

      def has_many(name, scope = nil, through: nil, **options, &block)
        raise TypeError, "has_many through is unsupported" if through
        add_reflection(name, scope, options, :has_many, block)
      end

      private

      def resource_reflections
        @resource_reflections ||= {}
      end

      def add_reflection(name, scope, options, macro, block)
        resource_reflections[name.to_s] = ResourceReflection.new(name, scope, options, macro, block)
      end

      class ResourceReflection
        attr_reader :name, :scope, :options, :macro, :block

        def initialize(name, scope, options, macro, block)
          @name = name
          @scope = scope
          @options = options
          @macro = macro
          @block = block
        end

        def reflection(model_klass)
          if macro == :has_many
            ::ActiveRecord::Associations::Builder::HasMany.create_reflection(model_klass, name, scope, options)
          elsif macro == :belongs_to
            ::ActiveRecord::Associations::Builder::BelongsTo.create_reflection(model_klass, name, scope, options)
          end
        end
      end

      class UpdatedReflection
        attr_reader :name, :block

        def initialize(name, block)
          @name = name
          @block = block
        end

        def reflection(model_klass)
          model_klass.reflect_on_association(name)
        end
      end
    end
  end
end
