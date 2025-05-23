# frozen_string_literal: true

# rbs_inline: enabled

require "synvert/core"
require "standard"

module AlbaMigration
  class Snippet
    module SuperclassRewritable
      # @rbs return: Synvert::Core::Rewriter
      def superclass_rewriter
        migrate_file_path = @migrate_file_path

        Synvert::Core::Rewriter.new "alba_migration", "rewrite_superclass" do
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
              body_src = node.body ? node.body.to_source : ""
              replace_with "class #{node.constant_path.to_source}\ninclude Alba::Resource\n\n#{body_src}\nend"
            end

            # Convert lambda syntax to proc syntax in if option
            with_node node_type: "lambda_node" do
              body_src = node.body ? node.body.to_source : ""
              replace_with "proc { #{body_src} }"
            end

            # Convert attribute method to attributes method only if it has an if condition
            with_node node_type: "call_node", receiver: nil, message: "attribute" do
              # Check if this attribute call has an 'if' argument
              has_if_option = false
              if node.arguments&.arguments
                node.arguments.arguments.each do |arg|
                  if arg.type == :keyword_hash_node && arg.elements
                    arg.elements.each do |element|
                      if element.type == :assoc_node && element.key.type == :symbol_node && element.key.unescaped == "if"
                        has_if_option = true
                        break
                      end
                    end
                  end
                end
              end

              if has_if_option
                # Get all arguments
                args = node.arguments ? node.arguments.arguments.map(&:to_source).join(", ") : ""
                replace_with "attributes #{args}"
              end
            end
          end

          Standard::Cli.new(["--fix", Array(migrate_file_path).join(" ")]).run
        end
      end
    end
  end
end
