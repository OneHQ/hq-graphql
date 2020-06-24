# frozen_string_literal: true

require "hq/graphql/types"

module HQ
  module GraphQL
    class PaginatedAssociationLoader < ::GraphQL::Batch::Loader
      def self.for(*args, scope: nil, **kwargs)
        if scope
          raise TypeError, "scope must be an ActiveRecord::Relation" unless scope.is_a?(::ActiveRecord::Relation)
          executor = ::GraphQL::Batch::Executor.current
          loader_key = loader_key_for(*args, **kwargs, scope: scope.to_sql)
          executor.loader(loader_key) { new(*args, **kwargs, scope: scope) }
        else
          super
        end
      end

      def initialize(model, association_name, internal_association: false, limit: nil, offset: nil, scope: nil, sort_by: nil, sort_order: nil)
        @model                = model
        @association_name     = association_name
        @internal_association = internal_association
        @limit                = [0, limit].max if limit
        @offset               = [0, offset].max if offset
        @scope                = scope
        @sort_by              = sort_by || :updated_at
        @sort_order           = normalize_sort_order(sort_order)

        validate!
      end

      def load(record)
        raise TypeError, "#{@model} loader can't load association for #{record.class}" unless record.is_a?(@model)
        super
      end

      def cache_key(record)
        record.send(primary_key)
      end

      def perform(records)
        values = records.map { |r| source_value(r) }
        scope  =
          if @limit || @offset
            # If a limit or offset is added, then we need to transform the query
            # into a lateral join so that we can limit on groups of data.
            #
            # > SELECT * FROM addresses WHERE addresses.user_id IN ($1, $2, ..., $N) ORDER BY addresses.created_at DESC;
            # ...becomes
            # > SELECT DISTINCT a_top.*
            # > FROM addresses
            # > INNER JOIN LATERAL (
            # >   SELECT inner.*
            # >   FROM addresses inner
            # >   WHERE inner.user_id = addresses.user_id
            # >   ORDER BY inner.created_at DESC
            # >   LIMIT 1
            # > ) a_top ON TRUE
            # > WHERE addresses.user_id IN ($1, $2, ..., $N)
            # > ORDER BY a_top.created_at DESC
            inner_table        = association_class.arel_table
            lateral_join_table = through_reflection? ? through_association.klass.arel_table : inner_table
            from_table         = lateral_join_table.alias("outer")

            inside_scope = default_scope.
              select(inner_table[::Arel.star]).
              from(inner_table).
              where(lateral_join_table[target_join_key].eq(from_table[target_join_key])).
              reorder(arel_order(inner_table)).
              limit(@limit).
              offset(@offset)

            if through_reflection?
              # expose the through_reflection key
              inside_scope = inside_scope.select(lateral_join_table[target_join_key])
            end

            lateral_table = ::Arel::Table.new("top")
            association_class.
              select(lateral_table[::Arel.star]).distinct.
              from(from_table).
              where(from_table[target_join_key].in(values)).
              joins("INNER JOIN LATERAL (#{inside_scope.to_sql}) #{lateral_table.name} ON TRUE").
              reorder(arel_order(lateral_table))
          else
            scope = default_scope.reorder(arel_order(association_class.arel_table))

            if through_reflection?
              scope.where(through_association.name => { target_join_key => values }).
                # expose the through_reflection key
                select(association_class.arel_table[::Arel.star], through_association.klass.arel_table[target_join_key])
            else
              scope.where(target_join_key => values)
            end
          end

        results = scope.to_a
        records.each do |record|
          fulfill(record, target_value(record, results)) unless fulfilled?(record)
        end
      end

      private

      def source_join_key
        belongs_to? ? association.foreign_key : association.association_primary_key
      end

      def source_value(record)
        record.send(source_join_key)
      end

      def target_join_key
        if through_reflection?
          through_association.foreign_key
        elsif belongs_to?
          association.association_primary_key
        else
          association.foreign_key
        end
      end

      def target_value(record, results)
        enumerator = has_many? ? :select : :detect
        results.send(enumerator) { |r| r.send(target_join_key) == source_value(record) }
      end

      def default_scope
        scope = association_class
        scope = association.scopes.reduce(scope, &:merge)
        scope = association_class.default_scopes.reduce(scope, &:merge)
        scope = scope.merge(@scope) if @scope

        if through_reflection?
          source = association_class.arel_table
          target = through_association.klass.arel_table
          join   = source.join(target).on(target[association.foreign_key].eq(source[source_join_key]))
          scope  = scope.joins(join.join_sources)
        end

        scope
      end

      def belongs_to?
        association.macro == :belongs_to
      end

      def has_many?
        association.macro == :has_many
      end

      def through_association
        association.through_reflection
      end

      def through_reflection?
        association.through_reflection?
      end

      def association
        if @internal_association
          Types[@model].reflect_on_association(@association_name)
        else
          @model.reflect_on_association(@association_name)
        end
      end

      def association_class
        association.klass
      end

      def primary_key
        @model.primary_key
      end

      def arel_order(table)
        table[@sort_by].send(@sort_order)
      end

      def normalize_sort_order(input)
        if input.to_s.casecmp("asc").zero?
          :asc
        else
          :desc
        end
      end

      def validate!
        raise ArgumentError, "No association #{@association_name} on #{@model}" unless association
      end
    end
  end
end
