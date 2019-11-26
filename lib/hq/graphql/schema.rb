# frozen_string_literal: true

module HQ
  module GraphQL
    class Schema < ::GraphQL::Schema
      class << self
        def dump_directory
          raise ::NotImplementedError
        end

        def dump_filename
          raise ::NotImplementedError
        end

        def dump
          ::FileUtils.mkdir_p(dump_directory)
          ::File.open(::File.join(dump_directory, dump_filename), "w") { |file| file.write(self.to_definition) }
        end
      end
    end
  end
end
