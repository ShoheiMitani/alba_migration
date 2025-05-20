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
          end

          Standard::Cli.new(["--fix", Array(migrate_file_path).join(" ")]).run
        end
      end
    end
  end
end
