# frozen_string_literal: true

module HQ
  module GraphQL
    # Wording for an authorization refusal, shared by a mutation's own check and
    # by the nested-attribute walk so a client hears one voice whether the
    # refusal was about the mutation's model or something inside its payload.
    module AuthorizationMessage
      # `destroy` is the ActiveRecord name for it; "delete" is the word a person
      # reading the message expects.
      VERBS = {
        create: "create",
        update: "update",
        destroy: "delete",
        copy: "copy"
      }.freeze

      # "HasContactInfo::Website" reads as "websites". Goes through
      # `model_name.human` so an app can override the wording in its locale.
      def self.for(action, klass)
        "You are not allowed to #{verb(action)} #{subject(klass)}"
      end

      def self.verb(action)
        VERBS.fetch(action.to_sym, action.to_s)
      end
      private_class_method :verb

      def self.subject(klass)
        klass.model_name.human.downcase.pluralize
      end
      private_class_method :subject
    end
  end
end
