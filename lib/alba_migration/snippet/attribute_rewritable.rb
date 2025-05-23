# frozen_string_literal: true

# rbs_inline: enabled

require "synvert/core"
require "standard"

module AlbaMigration
  class Snippet
    module AttributeRewritable
      # @rbs return: Synvert::Core::Rewriter
      def attribute_method_rewriter
        migrate_file_path = @migrate_file_path

        Synvert::Core::Rewriter.new "alba_migration", "rewrite_attribute_method" do
          description <<~EOS
            It migrates ActiveModelSerializers attribute syntax to Alba attribute syntax.
                  
            Example:
      
            # 1. Simple attribute methods grouped
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

            # 2. attribute with block
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

            # 3. attribute :name + def name ... end
            ```ruby
            class AttributeResource
              attribute :user_name
              def user_name
                object.user.name
              end
            end
            ```

            =>

            ```ruby
            class AttributeResource
              attribute :user_name do |object|
                object.user.name
              end
            end
            ```

            # 4. attributes :a, :b, ... + def a ... end
            ```ruby
            class AttributeResource
              attributes :user_name, :user_id
              def user_name
                object.user.name
              end
              def user_id
                object.user.id
              end
            end
            ```

            =>

            ```ruby
            class AttributeResource
              attribute :user_name do |object|
                object.user.name
              end
              attribute :user_id do |object|
                object.user.id
              end
            end
            ```
          EOS

          configure(parser: "parser")

          within_files migrate_file_path do
            # Rewrite the entire class at once
            with_node type: "class" do
              class_name = node.children[0].loc.expression.source
              superclass_node = node.children[1]
              superclass_src = superclass_node ? " < #{superclass_node.loc.expression.source}" : ""
              class_body = node.children[2]

              # If class_body is a :begin node, loop through its children. Otherwise, treat it as a single node in an array.
              body_nodes = if class_body && class_body.type == :begin
                class_body.children
              elsif class_body
                [class_body]
              else
                []
              end

              # Pre-collect conversion data
              attribute_blocks = {}  # Conversion results for block-based attributes
              attr_names = {}        # Combination of attribute :name + def name
              attributes_groups = {} # Grouped attributes :a, :b
              def_method_names = []  # List of def method names

              # 0. Pre-collect def method names
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                if child.type == :def
                  def_method_names << child.children[0].to_s
                end
              end

              # 1. Collect attribute(:xxx) { ... } blocks
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                if child.type == :block &&
                    child.children[0] && child.children[0].is_a?(Parser::AST::Node) && child.children[0].type == :send &&
                    child.children[0].children[1] == :attribute

                  arg_node = child.children[0].children[2]
                  arg = if arg_node.is_a?(Parser::AST::Node) && arg_node.type == :sym
                    ":#{arg_node.children[0]}"
                  else
                    arg_node.to_s
                  end

                  block_params = child.children[1] ? child.children[1].children.map { |c| c.children[0].to_s }.join(", ") : ""
                  block_body = child.children[2] ? child.children[2].loc.expression.source : ""

                  if block_params.strip.empty? && block_body.include?("object")
                    block_params = "object"
                  end

                  converted = if block_params.strip.empty?
                    "  attribute #{arg} do\n    #{block_body}\n  end"
                  else
                    "  attribute #{arg} do |#{block_params.strip}|\n    #{block_body}\n  end"
                  end

                  attribute_blocks[child] = converted
                end
              end

              # 2. Collect attribute :name + def name combinations
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                if child.type == :send &&
                    child.children[1] == :attribute &&
                    child.children.length == 3 &&
                    child.children[2].is_a?(Parser::AST::Node) &&
                    child.children[2].type == :sym

                  attr_name = child.children[2].children[0].to_s
                  attr_names[attr_name] = child
                end
              end

              # 3. Process attributes :a, :b grouping
              standalone_attributes = []
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                if child.type == :send && child.children[1] == :attribute && child.children.length == 3 && child.children[2].is_a?(Parser::AST::Node) && child.children[2].type == :sym
                  method_name = child.children[2].children[0].to_s
                  unless body_nodes.any? { |c| c.is_a?(Parser::AST::Node) && c.type == :def && c.children[0].to_s == method_name }
                    standalone_attributes << ":#{method_name}"
                  end
                elsif child.type == :send && child.children[1] == :attributes
                  if child.children.length >= 3 && child.children[2].is_a?(Parser::AST::Node)
                    arg_node = child.children[2]
                    attrs_from_this_node = []
                    if arg_node.type == :array
                      syms = arg_node.children.select { |n| n.is_a?(Parser::AST::Node) && n.type == :sym }
                      syms.each { |sym_node| attrs_from_this_node << ":#{sym_node.children[0]}" }
                    elsif arg_node.type == :sym_array
                      arg_node.children.each { |sym_lit| attrs_from_this_node << ":#{sym_lit}" }
                    else
                      # For multiple arguments case (attributes :a, :b)
                      child.children[2..].each do |arg|
                        if arg.is_a?(Parser::AST::Node) && arg.type == :sym
                          attrs_from_this_node << ":#{arg.children[0]}"
                        end
                      end
                    end

                    # Keep only those not converted by def methods
                    remaining_attrs = attrs_from_this_node.reject do |attr_name|
                      method_name = attr_name[1..] # Remove :
                      def_method_names.include?(method_name)
                    end

                    attributes_groups[child] = remaining_attrs
                  end
                end
              end

              # Main processing: process body_nodes sequentially
              new_lines = ["class #{class_name}#{superclass_src}"]

              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)

                case child.type
                when :send
                  if child.children[1] == :include
                    # include Alba::Resource
                    new_lines << "  " + child.loc.expression.source
                    new_lines << ""
                  elsif child.children[1] == :attribute && child.children.length == 3 && child.children[2].is_a?(Parser::AST::Node) && child.children[2].type == :sym
                    # attribute :xxx
                    method_name = child.children[2].children[0].to_s
                    def_exists = body_nodes.any? { |c| c.is_a?(Parser::AST::Node) && c.type == :def && c.children[0].to_s == method_name }

                    if def_exists
                      # Do nothing if def method exists (convert at def processing)
                      next
                    elsif child.children.length > 3
                      # Unsupported attribute with options
                      new_lines << "  " + child.loc.expression.source
                    else
                      # Output as standalone attribute grouping (only once)
                      unless standalone_attributes.empty?
                        new_lines << "  attributes #{standalone_attributes.join(", ")}"
                        new_lines << ""
                        standalone_attributes.clear
                      end
                    end
                  elsif child.children[1] == :attributes
                    # attributes :xxx, :yyy, ...
                    if attributes_groups[child]
                      unless attributes_groups[child].empty?
                        new_lines << "  attributes #{attributes_groups[child].join(", ")}"
                        new_lines << ""
                      end
                    else
                      # Unsupported attributes syntax
                      new_lines << "  " + child.loc.expression.source
                    end
                  else
                    # Other method calls (including unsupported syntax)
                    new_lines << "  " + child.loc.expression.source
                  end

                when :block
                  new_lines << (attribute_blocks[child] || "  " + child.loc.expression.source)

                when :def
                  method_name = child.children[0].to_s
                  method_body = child.children[2]
                  method_src = method_body ? method_body.loc.expression.source : ""

                  if attr_names.key?(method_name)
                    # Convert attribute :name + def name
                    new_lines << "  attribute :#{method_name} do |object|"
                    new_lines << "    #{method_src}"
                    new_lines << "  end"
                  elsif method_src.strip.start_with?("object.") || (method_name.end_with?("s") && method_body)
                    # Convert def methods containing object.xxx
                    new_lines << "  attribute :#{method_name} do |object|"
                    new_lines << "    #{method_src}"
                    new_lines << "  end"
                  else
                    # Non-convertible def methods
                    new_lines << "  " + child.loc.expression.source
                  end

                else
                  # Other nodes
                  new_lines << "  " + child.loc.expression.source
                end
              end

              new_lines << "end"

              # Remove consecutive blank lines
              final_code = new_lines.each_with_object([]) do |line, arr|
                if line.strip.empty? && arr.last&.strip&.empty?
                  next
                end
                arr << line
              end.join("\n")

              replace_with final_code
            end
          end

          Standard::Cli.new(["--fix", Array(migrate_file_path).join(" ")]).run
        end
      end
    end
  end
end
