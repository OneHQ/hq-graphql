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
        scope =
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
            inner_table       = association_class.arel_table
            association_table = inner_table.alias("outer")

            inside_scope = default_scope.
              select(inner_table[::Arel.star]).
              from(inner_table).
              where(inner_table[association_key].eq(association_table[association_key])).
              reorder(arel_order(inner_table)).
              limit(@limit).
              offset(@offset)

            outside_table = ::Arel::Table.new("top")
            association_class.
              select(outside_table[::Arel.star]).distinct.
              from(association_table).
              joins("INNER JOIN LATERAL (#{inside_scope.to_sql}) #{outside_table.name} ON TRUE").
              where(association_table[association_key].in(records.map { |r| join_value(r) })).
              reorder(arel_order(outside_table))
          else
            default_scope.
              reorder(arel_order(association_class.arel_table)).
              where(association_key => records.map { |r| join_value(r) })
          end

        results = scope.to_a
        records.each do |record|
          fulfill(record, association_value(record, results)) unless fulfilled?(record)
        end
      end

      private

      def association_key
        belongs_to? ? association.association_primary_key : association.foreign_key
      end

      def association_value(record, results)
        enumerator = has_many? ? :select : :detect
        results.send(enumerator) { |r| r.send(association_key) == join_value(record) }
      end

      def join_key
        belongs_to? ? association.foreign_key : association.association_primary_key
      end

      def join_value(record)
        record.send(join_key)
      end

      def default_scope
        scope = association_class
        scope = association.scopes.reduce(scope, &:merge)
        scope = association_class.default_scopes.reduce(scope, &:merge)
        scope = scope.merge(@scope) if @scope
        scope
      end

      def belongs_to?
        association.macro == :belongs_to
      end

      def has_many?
        association.macro == :has_many
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
