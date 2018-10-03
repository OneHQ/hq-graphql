require "graphql"

module HQ
  module GraphQL
    def self.config
      @config ||= ::ActiveSupport::OrderedOptions.new
    end

    def self.configure(&block)
      config.instance_eval(&block)
    end

    # The gem assumes that if your model is called `MyModel`, the corresponding type is `MyModelType`.
    # You can override that convention.
    #
    # ::HQ::GraphQL.config do |config|
    #   config.model_to_graphql_type = -> (model_class) { "::CustomNameSpace::#{model_class.name}Type" }
    # end
    def self.model_to_graphql_type
      config.model_to_graphql_type ||
        @model_to_graphql_type ||= -> (model_class) { "#{model_class.name.demodulize}Type" }
    end

    def self.graphql_type_from_model(model_class)
      model_to_graphql_type.call(model_class)
    end
  end
end

require "hq/graphql/types"
require "hq/graphql/object"
require "hq/graphql/engine"
