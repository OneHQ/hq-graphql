# frozen_string_literal: true

module HQ
  module GraphQL
    module Ext
      module SchemaExtensions
        MAX_RESULTS = 250

        module Prepend
          def self.prepended(klass)
            klass.alias_method :add_type_and_traverse_without_types, :add_type_and_traverse
            klass.alias_method :add_type_and_traverse, :add_type_and_traverse_with_types
          end

          def multiplex(*args, **options)
            load_types!
            super
          end

          def dump_directory(directory = Rails.root.join("app/graphql"))
            @dump_directory ||= directory
          end

          def dump_filename(filename = "#{self.name.underscore}.graphql")
            @dump_filename ||= filename
          end

          def dump
            load_types!
            ::FileUtils.mkdir_p(dump_directory)
            ::File.open(::File.join(dump_directory, dump_filename), "w") { |file| file.write(self.to_definition) }
          end

          def load_types!
            ::HQ::GraphQL.load_types!
            return if @add_type_and_traverse_with_types.blank?
            while (args, options = @add_type_and_traverse_with_types.shift)
              add_type_and_traverse_without_types(*args, **options)
            end
          end

          # Defer adding types until first schema execution
          # https://github.com/rmosolgo/graphql-ruby/blob/345ebb2e3833909963067d81e0e8378717b5bdbf/lib/graphql/schema.rb#L1792
          def add_type_and_traverse_with_types(*args, **options)
            @add_type_and_traverse_with_types ||= []
            @add_type_and_traverse_with_types.push([args, options])
          end
        end
        module Include
          # Force pagination queries limit
          def self.included(klass)
            super
            klass.default_max_page_size MAX_RESULTS
          end
        end
      end
    end
  end
end

::GraphQL::Schema.singleton_class.prepend ::HQ::GraphQL::Ext::SchemaExtensions::Prepend
::GraphQL::Schema.include ::HQ::GraphQL::Ext::SchemaExtensions::Include
