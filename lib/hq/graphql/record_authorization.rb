# frozen_string_literal: true

module HQ
  module GraphQL
    # Authorizes the record a generated mutation writes AS A CHILD of whoever it belongs to.
    #
    # `ready?` only ever asks "may I update SalesManager?", which is the model's own
    # question. A host that scopes restrictions per parent (`Advisor -> SalesManager`,
    # distinct from `Opportunity -> SalesManager`) authors them under the parent, so that
    # question can never find them: a role forbidden to update an advisor's sales managers
    # could still update one through `updateSalesManager`, because nothing in the
    # mutation says whose it is. The record knows, so the gem asks about it.
    #
    # Inert until the host sets BOTH hooks:
    #
    #   config.record_parents = ->(record, context) { [Advisor] }
    #     Who the record belongs to: the parent classes to ask about, an empty list for
    #     none. Only the host knows what "belongs to" means for its models. Return EVERY
    #     owner the record has: one that allows several is restricted under each of them,
    #     and each parent returned is asked about.
    #
    #   config.authorize_nested_attributes
    #     Answers each question. It is the hook already used for the rows a mutation
    #     reaches through nested attributes, and means the same thing here: "may this
    #     user `action` a `klass` as a child of `parent_klass`?".
    #
    # The record is the one the mutation found, or built, so the owner is read from the
    # real thing instead of being worked out from the arguments. An update is asked
    # about the owners the record has and, once the attributes are assigned, about any new
    # ones it would be left with -- as a CREATE, since handing a record to a new owner is
    # adding it there, which the role on the old owner does not cover. A refusal writes
    # nothing.
    module RecordAuthorization
      class << self
        # The refusal message when `action` on `record` is not allowed under one of `parents`
        # (the record's own when not given), or nil.
        def refusal(action, record, context, parents: nil)
          (parents || self.parents(record, context)).each do |parent|
            next if ::HQ::GraphQL.authorize_nested_attributes(action, record.class, parent, context)

            return ::HQ::GraphQL::AuthorizationMessage.for(action, record.class)
          end

          nil
        end

        # The parent classes the host says the record belongs to.
        def parents(record, context)
          hook = ::HQ::GraphQL.config.record_parents
          return [] unless hook

          Array(hook.call(record, context)).compact.uniq
        end

        # The payload a refusal is answered with: the same shape and wording as a
        # mutation the model's own check denied.
        def payload(message)
          { resource: nil, errors: { "base" => [message] } }
        end
      end
    end
  end
end
