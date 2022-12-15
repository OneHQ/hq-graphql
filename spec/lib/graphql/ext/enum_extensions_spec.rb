require "rails_helper"

describe ::HQ::GraphQL::Ext::EnumExtensions do
  let(:advisor1) { FactoryBot.create(:advisor, :simple_name) }
  let(:advisor2) { FactoryBot.create(:advisor, :simple_name) }

  def build_enum(**args)
    Class.new(::GraphQL::Schema::Enum).tap do |klass|
      klass.class_exec(**args) do |**a|
        graphql_name "Advisor"
        with_model Advisor, **a
      end
    end
  end

  it "raises an error if the ActiveRecord class can't be inferred from the class name" do
    expect { Class.new(::GraphQL::Schema::Enum) { with_model } }.to raise_error ArgumentError
  end

  it "generates an enum with default values" do
    expected_keys = [advisor1.name, advisor2.name].map { |name| name.delete(" ") }

    enum = build_enum
    expect(enum.values).to be_empty
    enum.lazy_load!
    expect(enum.values.keys).to contain_exactly(*expected_keys)
    expect(enum.values.values.map(&:value)).to contain_exactly(advisor1, advisor2)
  end

  it "globally registers an enum" do
    enum = build_enum
    expect(::HQ::GraphQL.enums).to contain_exactly(Advisor)
    expect(::HQ::GraphQL::Types[Advisor]).to eq enum
  end

  it "disables registration" do
    build_enum(register: false)
    expect(::HQ::GraphQL.enums).to be_empty
    expect { ::HQ::GraphQL::Types[Advisor] }.to raise_error ::HQ::GraphQL::Types::Error
  end

  it "supports scoping" do
    expected_keys = [advisor1.name.delete(" ")]

    organization_id = advisor1.organization_id
    enum = build_enum(scope: -> { where(organization_id: organization_id) })

    enum.lazy_load!
    expect(enum.values.keys).to contain_exactly(*expected_keys)
    expect(enum.values.values.map(&:value)).to contain_exactly(advisor1)
  end

  it "supports prefixes" do
    expected_keys = ["OneHQ#{advisor1.name.delete(" ")}"]

    enum = build_enum(prefix: "OneHQ")
    enum.lazy_load!
    expect(enum.values.keys).to contain_exactly(*expected_keys)
    expect(enum.values.values.map(&:value)).to contain_exactly(advisor1)
  end

  it "supports value method override" do
    advisor1.update(nickname: "Ricky Bobby")

    enum = build_enum(value_method: :nickname)
    enum.lazy_load!
    expect(enum.values.keys).to contain_exactly(advisor1.nickname.delete(" "))
    expect(enum.values.values.map(&:value)).to contain_exactly(advisor1)
  end
end
