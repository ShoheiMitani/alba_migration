# frozen_string_literal: true

# rbs_inline: enabled

require "synvert/core"
require "standard"

module AlbaMigration
  class Snippet
    # @rbs migrate_file_path: String
    # @rbs return: Array[Synvert::Core::Rewriter]
    def self.snippets(migrate_file_path:)
      snippet_creator = new(migrate_file_path:)
      [
        snippet_creator.superclass_rewriter,
        snippet_creator.attribute_method_rewriter
      ]
    end

    # @rbs migrate_file_path: String
    # @rbs return: void
    def initialize(migrate_file_path:)
      @migrate_file_path = migrate_file_path
    end

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

    # @rbs return: Synvert::Core::Rewriter
    def attribute_method_rewriter
      migrate_file_path = @migrate_file_path

      Synvert::Core::Rewriter.new "alba_migration", "rewrite_attribute_method" do
        description <<~EOS
          It migrates ActiveModelSerializers attribute syntax to Alba attribute syntax.
      
          Example:
      
          ```ruby
          class AttributeResource
            attribute(:object)
            attribute(:user_id)
            attribute :user_name
          end
          ```

          =>

          ```ruby
          class AttributeResource
            attributes :object, :user_id, :user_name
          end
          ```
  
          ```ruby
          class AttributeResource
            attribute(:object) { 'access_token' }
            attribute(:user_id) { object.user_id }
            attribute :user_name
            def user_name
              object.user.name
            end
          end
          ```

          =>

          ```ruby
          class AttributeResource
            attribute :object do
              'access_token'
            end
            attribute :user_id do |object|
              object.user_id
            end
            attribute :user_name do |object|
              object.user.name
            end
          end
          ```
        EOS

        configure(parser: "parser")

        within_files migrate_file_path do
          # Rewrite the entire class at once
          with_node type: "class" do
            class_name = node.children[0].loc.expression.source
            class_body = node.children[2]
            next unless class_body

            # 1. Collect attribute blocks
            attribute_blocks = []
            other_lines = []

            # Collect other lines in the class
            class_body.children.each do |child|
              if child && child.type == :send
                if child.children[1] == :include || child.children[1] == :attributes
                  other_lines << "  " + child.loc.expression.source
                end
              end
            end

            # 1-1. Collect attribute(:xxx) { ... } style
            class_body.children.each do |child|
              if child && child.type == :block &&
                  child.children[0] && child.children[0].type == :send &&
                  child.children[0].children[1] == :attribute

                # Process arguments
                arg_node = child.children[0].children[2]
                arg = (arg_node.type == :sym) ? ":#{arg_node.children[0]}" : arg_node.loc.expression.source

                # Process block parameters
                block_params = child.children[1] ? child.children[1].children.map { |c| c.children[0].to_s }.join(", ") : ""

                # Process block body
                block_body = child.children[2] ? child.children[2].loc.expression.source : ""

                # Add 'object' to parameters if used in block body
                if block_params.strip.empty? && block_body.include?("object")
                  block_params = "object"
                end

                # Generate new code（インデント付与はしない）
                attribute_blocks << if block_params.strip.empty?
                  "attribute #{arg} do\n#{block_body}\nend"
                else
                  "attribute #{arg} do |#{block_params.strip}|\n#{block_body}\nend"
                end
              end
            end

            # 1-2. Collect attribute :name + def name ... end style
            attr_names = {}
            other_methods = []

            # First, collect attribute :name
            class_body.children.each do |child|
              if child && child.type == :send &&
                  child.children[1] == :attribute &&
                  child.children.length == 3 &&
                  child.children[2].type == :sym

                attr_name = child.children[2].children[0].to_s
                attr_names[attr_name] = nil
              end
            end

            # Extract attribute names to be grouped as attributes
            attributes_group = []
            class_body.children.each do |child|
              if child && child.type == :send &&
                  child.children[1] == :attribute &&
                  child.children.length == 3 &&
                  child.children[2].type == :sym
                method_name = child.children[2].children[0].to_s
                # Only group as attributes if there is no corresponding def method
                unless class_body.children.any? { |c| c && c.type == :def && c.children[0].to_s == method_name }
                  attributes_group << ":#{method_name}"
                end
              end
            end

            # 2. Generate new code for the entire class
            new_lines = ["class #{class_name}"]

            # Add attributes group at the top
            unless attributes_group.empty?
              new_lines << "  attributes #{attributes_group.join(", ")}"
            end

            # Add include and attributes lines
            if !other_lines.empty?
              include_line = other_lines.find { |line| line.include?("include") }
              attribute_lines = other_lines.select { |line| !line.include?("include") }

              # Add include first
              new_lines << include_line if include_line

              # Add a blank line
              new_lines << ""

              # Add attributes lines
              new_lines.concat(attribute_lines) unless attribute_lines.empty?
            end

            # 2-1. Add attribute blocks (no extra blank lines)
            new_lines.concat(attribute_blocks)

            # Convert attribute :name + def name ... end pairs
            class_body.children.each do |child|
              if child && child.type == :def
                method_name = child.children[0].to_s
                if attr_names.key?(method_name)
                  # Method corresponding to attribute (to be converted)
                  method_body = child.children[2]
                  method_src = method_body ? method_body.loc.expression.source : ""
                  # No indent
                  attr_names[method_name] = "attribute :#{method_name} do |object|\n#{method_src}\nend"
                elsif child.respond_to?(:loc) && child.loc.respond_to?(:expression)
                  # Methods not corresponding to attribute (preserved)
                  method_src = child.loc.expression.source
                  other_methods << method_src
                end
              end
            end

            # 2-2. Add conversion results of attribute :name + def name ... end (no extra blank lines)
            attr_blocks = attr_names.values.compact
            new_lines.concat(attr_blocks)
            # 2-3. Add other methods (def not corresponding to attribute) (no extra blank lines)
            new_lines.concat(other_methods)

            new_lines << "end"

            replace_with new_lines.join("\n")
          end
        end

        Standard::Cli.new(["--fix", Array(migrate_file_path).join(" ")]).run
      end
    end
  end
end
