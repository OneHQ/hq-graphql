# frozen_string_literal: true

# typed: strict

module HQ
  module GraphQL
    class Config < T::Struct
      DefaultScopeProc = T.type_alias { T.proc.params(arg0: T.untyped, arg1: ::GraphQL::Query::Context).returns(T.untyped) }
      prop :default_scope, DefaultScopeProc, default: ->(scope, _context) { scope }
    end
  end
end
