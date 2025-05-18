# frozen_string_literal: true

Synvert::Core::Rewriter.new "alba", "convert_ams_to_alba" do
  description <<~EOS
    It converts ActiveModelSerializers syntax to Alba syntax.

    Example:

    ```ruby
    class AttributesResource < ActiveModel::Serializer
      attributes :id, :name
    end
    ```

    =>

    ```ruby
    class AttributesResource
      include Alba::Resource

      attributes :id, :name
    end
    ```
  EOS

  configure(parser: "prism")

  if_gem "active_model_serializers", ">= 0.10.0"

  within_files "app/serializers/**/*.rb" do
    with_node node_type: "class_node", superclass: "ActiveModel::Serializer" do
      body = node.body ? node.body.to_source : ""
      if body.strip.empty?
        indented_body = ""
      else
        min_indent = body.lines.reject { |l| l.strip.empty? }.map { |l| l[/^\s*/].size }.min || 0
        indented_body = body.lines.map { |l| "  " + l[min_indent..] }.join
      end
      replace_with "class #{node.constant_path.to_source}\n  include Alba::Resource\n\n#{indented_body}\nend"
    end
  end
end
