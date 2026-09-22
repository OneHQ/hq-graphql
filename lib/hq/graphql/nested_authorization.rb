# frozen_string_literal: true

module HQ
  module GraphQL
    # Authorizes the records a mutation reaches through NESTED ATTRIBUTES.
    #
    # A generated mutation only ever authorized its own model and action --
    # `ready?` asks "may I update Advisor?" and nothing else. Associations
    # writable through that mutation therefore bypassed their own resource
    # authorization entirely: a user forbidden to create a SalesManager could
    # still create one by sending it inside an Advisor update, because the
    # payload was never inspected.
    #
    # The action asked for each row is inferred the same way ActiveRecord
    # decides what to do with it: a primary key means update, `_destroy` means
    # destroy, and neither means create. The owner is passed as the parent so a
    # host scoping restrictions per parent (Advisor -> SalesManager distinct
    # from Opportunity -> SalesManager) resolves them the same way it does for
    # reads.
    #
    # Inert unless the host sets `config.authorize_nested_attributes`.
    module NestedAuthorization
      # The value an `X` input carries when the row is to be removed; see
      # `destroy?`.
      DESTROY_MARKER = "X"

      class << self
        # => { "salesManagers" => ["You are not allowed to create sales managers"] }
        # Keyed by the input field the client sent, so a caller can map the
        # refusal back to what it submitted. Empty when everything checks out.
        def errors(model_klass, attributes, context)
          collect(model_klass, attributes, context, {})
        end

        private

        def collect(klass, attributes, context, errors)
          return errors unless klass.is_a?(Class) && attributes.is_a?(Hash)

          attributes.each do |key, value|
            name = key.to_s
            next unless name.end_with?("_attributes")

            association = klass.reflect_on_association(name.delete_suffix("_attributes"))
            next if association.nil? || association.options[:polymorphic]

            association_klass = association.klass
            rows = value.is_a?(Array) ? value : [value]

            rows.each do |row|
              next unless row.is_a?(Hash)

              action = action_for(row, association_klass)
              unless ::HQ::GraphQL.authorize_nested_attributes(action, association_klass, klass, context)
                list = errors[association.name.to_s.camelize(:lower)] ||= []
                message = ::HQ::GraphQL::AuthorizationMessage.for(action, association_klass)
                list << message unless list.include?(message)
              end

              # Nesting goes as deep as the inputs allow, and every level is a
              # write the user has to be allowed to make.
              collect(association_klass, row, context, errors)
            end
          end

          errors
        rescue ::ActiveRecord::ActiveRecordError
          # A reflection that cannot resolve its class is not a write we can
          # judge; leave it to the model layer rather than failing the mutation.
          errors
        end

        def action_for(row, klass)
          return :destroy if destroy?(row)

          lookup(row, klass.primary_key).present? ? :update : :create
        end

        # Two ways a row asks to be removed. `_destroy` is the ActiveRecord one.
        # `X` is this gem's: `format_nested_attributes` maps the `x` input key to
        # `:X`, and a host defines an `X=` writer that calls
        # `mark_for_destruction`. A row deleting itself that way still carries
        # its id, so without this it reads as an update and a delete restriction
        # never fires.
        def destroy?(row)
          return true if lookup(row, "X") == DESTROY_MARKER

          ::ActiveRecord::Type::Boolean.new.cast(lookup(row, "_destroy")).present?
        end

        def lookup(row, key)
          row.key?(key.to_sym) ? row[key.to_sym] : row[key.to_s]
        end
      end
    end
  end
end
