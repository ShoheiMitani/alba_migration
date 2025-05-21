# frozen_string_literal: true

Synvert::Rewriter.new("custom_snippet", "rename_class_name") do
  configure(parser: "parser")

  within_files "app/serializers/attributes_serializer.rb" do
    with_node type: "class", name: "AttributesResource" do
      replace :name, with: "CustomAttributesResource"
    end
  end
end
