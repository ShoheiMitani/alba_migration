# frozen_string_literal: true

# rbs_inline: enabled

require "synvert"

module AlbaMigration
  class Snippet
    # @rbs file_patterns: Array[String]
    # @rbs return: Synvert::Core::Rewriter
    def self.create(migrate_file_path:)
      Synvert::Core::Rewriter.new "alba", "convert_ams_to_alba" do
        description <<~EOS
          It migrates ActiveModelSerializers syntax to Alba syntax.
      
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

        within_files migrate_file_path do
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
    end
  end
end
