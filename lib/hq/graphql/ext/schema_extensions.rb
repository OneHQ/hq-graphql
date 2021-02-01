# frozen_string_literal: true

module HQ
  module GraphQL
    module Ext
      module SchemaExtensions
        def self.prepended(klass)
          klass.alias_method :add_type_without_lazyload, :add_type
          klass.alias_method :add_type, :add_type_with_lazyload
        end

        def execute(*args, **options)
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
          return if @add_type_with_lazyload.blank?
          while (args, options = @add_type_with_lazyload.shift)
            add_type_without_lazyload(*args, **options)
          end
        end

        # Defer adding types until first schema execution
        # https://github.com/rmosolgo/graphql-ruby/blob/792f276444e1dd6004fcafe3820d65fdbbe285f0/lib/graphql/schema.rb#L1888-L1980
        def add_type_with_lazyload(*args, **options)
          @add_type_with_lazyload ||= []
          @add_type_with_lazyload.push([args, options])
        end
      end
    end
  end
end

::GraphQL::Schema.singleton_class.prepend ::HQ::GraphQL::Ext::SchemaExtensions
