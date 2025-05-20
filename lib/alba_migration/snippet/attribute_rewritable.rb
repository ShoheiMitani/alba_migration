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

              # Detect include Alba::Resource
              include_line = nil
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                if child.type == :send && child.children[1] == :include
                  include_line = "  " + child.loc.expression.source
                end
              end

              # 1-1. Collect attribute(:xxx) { ... } style
              attribute_blocks = []
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                if child.type == :block &&
                    child.children[0] && child.children[0].is_a?(Parser::AST::Node) && child.children[0].type == :send &&
                    child.children[0].children[1] == :attribute

                  # Process arguments
                  arg_node = child.children[0].children[2]
                  arg = if arg_node.is_a?(Parser::AST::Node) && arg_node.type == :sym
                    ":#{arg_node.children[0]}"
                  else
                    ((arg_node.respond_to?(:loc) && arg_node.loc.respond_to?(:expression)) ? arg_node.loc.expression.source : arg_node.to_s)
                  end

                  # Process block parameters
                  block_params = child.children[1] ? child.children[1].children.map { |c| c.children[0].to_s }.join(", ") : ""

                  # Process block body
                  block_body = child.children[2] ? child.children[2].loc.expression.source : ""

                  # Add 'object' to parameters if used in block body
                  if block_params.strip.empty? && block_body.include?("object")
                    block_params = "object"
                  end

                  # Generate new code (no indentation added)
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
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                if child.type == :send &&
                    child.children[1] == :attribute &&
                    child.children.length == 3 &&
                    child.children[2].is_a?(Parser::AST::Node) &&
                    child.children[2].type == :sym

                  attr_name = child.children[2].children[0].to_s
                  attr_names[attr_name] = nil
                end
              end

              # Extract attribute names to be grouped as attributes
              attributes_group = []
              attributes_methods = {}
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                # attribute :xxx
                if child.type == :send && child.children[1] == :attribute && child.children.length == 3 && child.children[2].is_a?(Parser::AST::Node) && child.children[2].type == :sym
                  method_name = child.children[2].children[0].to_s
                  unless body_nodes.any? { |c| c.is_a?(Parser::AST::Node) && c.type == :def && c.children[0].to_s == method_name }
                    attributes_group << ":#{method_name}"
                  end
                # attributes :xxx, :yyy, ...
                elsif child.type == :send && child.children[1] == :attributes
                  # attributes [:a, :b] or attributes %i[a b] style
                  if child.children.length == 3 && child.children[2].is_a?(Parser::AST::Node)
                    arg_node = child.children[2]
                    if arg_node.type == :array
                      syms = arg_node.children.select { |n| n.is_a?(Parser::AST::Node) && n.type == :sym }
                      syms.each { |sym_node| attributes_group << ":#{sym_node.children[0]}" }
                    elsif arg_node.type == :sym_array
                      # For %i[a b] style
                      arg_node.children.each do |sym_lit|
                        attributes_group << ":#{sym_lit}" # sym_lit is a Symbol
                      end
                    end
                  else
                    child.children[2..].each do |a|
                      if a.is_a?(Parser::AST::Node) && a.type == :sym
                        method_name = a.children[0].to_s
                        def_node = body_nodes.find { |c| c.is_a?(Parser::AST::Node) && c.type == :def && c.children[0].to_s == method_name }
                        if def_node
                          method_body = def_node.children[2]
                          method_src = method_body ? method_body.loc.expression.source : ""
                          attributes_methods[method_name] = "attribute :#{method_name} do |object|\n#{method_src}\nend"
                        else
                          attributes_group << ":#{method_name}"
                        end
                      end
                    end
                  end
                end
              end

              # 2. Generate new code for the entire class
              new_lines = ["class #{class_name}#{superclass_src}"]

              # Add include Alba::Resource first if present
              if include_line
                new_lines << include_line
                new_lines << ""
              end

              # Add attributes group after include
              unless attributes_group.empty?
                new_lines << "  attributes #{attributes_group.join(", ")}"
                new_lines << ""
              end

              # Add attribute blocks (no extra blank lines)
              new_lines.concat(attribute_blocks)

              # Convert attribute :name + def name ... end pairs
              attributeized_method_names = []
              body_nodes.each do |child|
                next unless child.is_a?(Parser::AST::Node)
                next unless child.type == :def
                method_name = child.children[0].to_s
                method_body = child.children[2]
                method_src = method_body ? method_body.loc.expression.source : ""
                # attribute :name + def name ... end
                if attr_names.key?(method_name)
                  attr_names[method_name] = "attribute :#{method_name} do |object|\n#{method_src}\nend"
                  attributeized_method_names << method_name
                  attributes_group.delete(":#{method_name}")
                  next
                end
                # attributes :name + def name ... end
                if attributes_methods.key?(method_name)
                  new_lines << attributes_methods[method_name]
                  attributeized_method_names << method_name
                  attributes_group.delete(":#{method_name}")
                  next
                end
                # def name ... object.xxx ... end
                if method_src.strip.start_with?("object.")
                  new_lines << "attribute :#{method_name} do |object|\n#{method_src}\nend"
                  attributeized_method_names << method_name
                  attributes_group.delete(":#{method_name}")
                  next
                end
                # def accounts ... object.account_id ... end (plural method names are converted as-is to attribute)
                if method_name.end_with?("s") && method_body
                  new_lines << "attribute :#{method_name} do |object|\n#{method_src}\nend"
                  attributeized_method_names << method_name
                  attributes_group.delete(":#{method_name}")
                  next
                end
                # All other methods go to other_methods (excluding those already converted to attribute)
                unless attributeized_method_names.include?(method_name)
                  method_src_full = child.loc.expression.source
                  other_methods << method_src_full
                end
              end

              # Add conversion results of attribute :name + def name ... end (no extra blank lines)
              attr_blocks = []
              attr_names.each do |k, _|
                def_node = body_nodes.find { |c| c.is_a?(Parser::AST::Node) && c.type == :def && c.children[0].to_s == k }
                if def_node && def_node.children[2] && def_node.children[2].loc.expression.source.strip.start_with?("object.")
                  method_src = def_node.children[2].loc.expression.source
                  attr_blocks << "attribute :#{k} do |object|\n#{method_src}\nend"
                  # Also remove from attributes_group
                  attributes_group.delete(":#{k}")
                end
              end
              new_lines.concat(attr_blocks)
              # Add other methods (def not corresponding to attribute) (no extra blank lines)
              filtered_other_methods = other_methods.reject do |src|
                attributeized_method_names.any? { |name| src.match?(/def\s+#{name}\b/) }
              end
              new_lines.concat(filtered_other_methods)

              new_lines << "end"

              # Remove consecutive blank lines except immediately after attributes or include Alba::Resource
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
