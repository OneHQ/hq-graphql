require 'rails_helper'

describe ::HQ::GraphQL::Ext::ActiveRecordExtensions do
  let(:extended_klass) do
    Class.new do
      include ::HQ::GraphQL::Ext::ActiveRecordExtensions

      @counter = 0

      lazy_load do
        @counter += 1
      end

      def self.counter
        @counter
      end
    end
  end

  describe ".add_attributes" do
    it "aliases add_attributes" do
      add_attributes = extended_klass.method(:add_attributes)
      aggregate_failures do
        expect(add_attributes).to eql(extended_klass.method(:add_attribute))
        expect(add_attributes).to eql(extended_klass.method(:add_attrs))
        expect(add_attributes).to eql(extended_klass.method(:add_attr))
      end
    end
  end

  describe ".remove_attributes" do
    it "aliases remove_attributes" do
      remove_attributes = extended_klass.method(:remove_attributes)
      aggregate_failures do
        expect(remove_attributes).to eql(extended_klass.method(:remove_attribute))
        expect(remove_attributes).to eql(extended_klass.method(:remove_attrs))
        expect(remove_attributes).to eql(extended_klass.method(:remove_attr))
      end
    end
  end

  describe ".add_associations" do
    it "aliases add_associations" do
      expect(extended_klass.method(:add_associations)).to eql(extended_klass.method(:add_association))
    end
  end

  describe ".remove_associations" do
    it "aliases remove_associations" do
      expect(extended_klass.method(:remove_associations)).to eql(extended_klass.method(:remove_association))
    end
  end

  describe ".lazy_load" do
    it "lazy loads once" do
      # First time it works
      expect { extended_klass.lazy_load! }.to change  { extended_klass.counter }.by(1)
      # Second time it does nothing
      expect { extended_klass.lazy_load! }.to change  { extended_klass.counter }.by(0)
    end
  end
end
