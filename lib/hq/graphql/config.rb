# frozen_string_literal: true

# typed: strict

module HQ
  module GraphQL
    class Config < T::Struct
      AuthorizeProc = T.type_alias { T.nilable(T.proc.params(action: T.untyped, object: T.untyped, context: ::GraphQL::Query::Context).returns(T::Boolean)) }
      prop :authorize, AuthorizeProc, default: nil

      AuthorizeFieldProc = T.type_alias { T.nilable(T.proc.params(action: T.untyped, field: ::HQ::GraphQL::Field, object: T.untyped, context: ::GraphQL::Query::Context).returns(T::Boolean)) }
      prop :authorize_field, AuthorizeFieldProc, default: nil

      DefaultScopeProc = T.type_alias { T.proc.params(arg0: T.untyped, arg1: ::GraphQL::Query::Context).returns(T.untyped) }
      prop :default_scope, DefaultScopeProc, default: ->(scope, _context) { scope }
    end
  end
end
