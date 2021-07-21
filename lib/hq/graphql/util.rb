# frozen_string_literal: true

module HQ
  module GraphQL
    module Util
      UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

      def self.validate_uuid(value)
        !value || !!value.to_s.match(UUID_FORMAT)
      end
    end
  end
end
