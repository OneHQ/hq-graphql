# frozen_string_literal: true

module HQ
  module GraphQL
    class Schema < ::GraphQL::Schema
      class << self
        def dump_directory(directory = Rails.root.join("app", "graphql"))
          @dump_directory ||= directory
        end

        def dump_filename(filename = "#{self.name.underscore}.graphql")
          @dump_filename ||= filename
        end

        def dump
          ::FileUtils.mkdir_p(dump_directory)
          ::File.open(::File.join(dump_directory, dump_filename), "w") { |file| file.write(self.to_definition) }
        end
      end
    end
  end
end
