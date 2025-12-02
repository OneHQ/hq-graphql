# frozen_string_literal: true

module HQ
  module GraphQL
    class Filters
      class RelativeDateExpression
        class << self
          def parse_boundary(value)
            payload = normalize_input(value)

            case payload
            when Hash
              interpret_hash(payload.deep_symbolize_keys)
            when String
              parse_absolute(payload)
            when Time, Date, DateTime
              payload
            when nil
              raise ArgumentError, "value can't be blank"
            else
              raise ArgumentError, "invalid date expression"
            end
          end

          def parse_range(value)
            payload = normalize_hash(value)
            from = parse_boundary(payload[:from])
            to = parse_boundary(payload[:to])

            if from.nil? || to.nil?
              raise ArgumentError, "date range filters require both \"from\" and \"to\" expressions"
            end

            [from, to]
          end

          private

          def interpret_hash(payload)
            kind = fetch_kind(payload)
            case kind
            when :relative
              raise ArgumentError, "relative field is required" if payload[:relative].blank?
              parse_relative(payload[:relative])
            when :anchor
              raise ArgumentError, "anchored field is required" if payload[:anchored].blank?
              parse_anchor(payload[:anchored])
            when :absolute
              raise ArgumentError, "absolute field is required" if payload[:absolute].blank?
              parse_absolute(payload[:absolute])
            end
          end

          def parse_absolute(payload)
            value = payload.is_a?(Hash) ? payload[:value] : payload
            raise ArgumentError, "value can't be blank" if value.blank?
            return value if value.is_a?(Time) || value.is_a?(DateTime)

            time = Time.iso8601(value.to_s)
            (Time.zone || ActiveSupport::TimeZone["UTC"]).at(time).utc
          rescue ArgumentError
            raise ArgumentError, "value must be an ISO8601 date"
          end

          def parse_relative(payload)
            amount = payload[:amount]
            raise ArgumentError, "relative expressions require an amount" if amount.nil?
            raise ArgumentError, "relative expressions require a positive amount" if amount.to_i <= 0
            raise ArgumentError, "relative expressions require a unit" if payload[:unit].blank?
            raise ArgumentError, "relative expressions require a direction" if payload[:direction].blank?

            unit = payload[:unit].to_s.downcase.singularize
            direction = payload[:direction].to_s.downcase

            multiplier = direction == "ago" ? -1 : 1
            offset = multiplier * amount.to_i
            now = current_time
            now + offset.public_send(unit)
          rescue NoMethodError
            raise ArgumentError, "unsupported unit #{payload[:unit]}"
          end

          def parse_anchor(payload)
            raise ArgumentError, "anchor expressions require a position" if payload[:position].blank?
            raise ArgumentError, "anchor expressions require a period" if payload[:period].blank?
            raise ArgumentError, "anchor expressions require an anchor" if payload[:anchor].blank?

            position = payload[:position].to_s.downcase
            period = payload[:period].to_s.downcase.singularize
            anchor = payload[:anchor].to_s.downcase

            offset = case position
            when "last" then -1
            when "next" then 1
            else 0
            end

            adjusted = current_time.advance(period_plural(period) => offset)
            method = anchor == "end_of" ? "end_of_#{period}" : "beginning_of_#{period}"
            adjusted.public_send(method)
          rescue NoMethodError
            raise ArgumentError, "unsupported anchor arguments"
          end

          def fetch_kind(payload)
            kind = payload[:kind]
            raise ArgumentError, "kind is required" if kind.blank?
            kind.to_s.downcase.to_sym
          end

          def normalize_input(value)
            return if value.nil?
            return value if value.is_a?(Hash) || value.is_a?(String) || value.is_a?(Time) || value.is_a?(Date) || value.is_a?(DateTime)

            if value.respond_to?(:to_h)
              value.to_h
            else
              value
            end
          end

          def normalize_hash(value)
            payload = normalize_input(value)
            unless payload.is_a?(Hash)
              raise ArgumentError, "date range filters expect an object with \"from\" and \"to\" keys"
            end

            payload.deep_symbolize_keys
          end

          def period_plural(period)
            "#{period}s".to_sym
          end

          def current_time
            Time.zone ? Time.zone.now : Time.now
          end
        end
      end
    end
  end
end
