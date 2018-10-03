class Query < HQ::GraphQL::Object
  graphql_name "Query"

  field :users, [HQ::GraphQL::Types[User]], null: false
  field :advisors, [HQ::GraphQL::Types[Advisor]], null: false

  def users
    User.all
  end

  def users_custom
    users
  end

  def advisors
    Advisor.all
  end
end
