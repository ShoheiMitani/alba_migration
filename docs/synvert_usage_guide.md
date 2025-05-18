# Synvert Usage Guideline

This document explains how to use the Synvert CLI to automate migration from ActiveModelSerializers to Alba, based on the actual implementation and DSL of synvert-core v2.2.2.

---

## 1. Overview

Synvert is an automated Ruby code refactoring tool. You define code transformation rules, and Synvert rewrites code based on AST (Abstract Syntax Tree) analysis for syntactically correct transformations.

Synvert consists of two main gems:
- `synvert-core` (v2.2.2): Provides core features (AST analysis, code transformation engine)
- `synvert` (v1.10.4): Provides the CLI interface and runs predefined or custom snippets

This project uses the `synvert` CLI for code transformation.

---

## 2. Installation and Basic Usage

### 2.1 Installation

```bash
gem install synvert
```

Or add to your Gemfile:

```ruby
gem 'synvert'
```

### 2.2 Basic Usage

```bash
# List available snippets
synvert -l

# Run a predefined snippet
synvert -r snippet_name

# Run a custom snippet file
synvert -s path/to/snippet.rb

# Run on a specific directory or file
synvert -s path/to/snippet.rb --path app/serializers

# Dry-run (no actual changes)
synvert -s path/to/snippet.rb --path app/serializers --dry-run
```

---

## 3. Writing Custom Snippets

### 3.1 Parser Selection

**Important:**
- Specify the parser as a string: `'parser'` (default), `'prism'`, or `'syntax_tree'`.
- Do **not** use constants like `Synvert::PRISM_PARSER` in the DSL.

#### Example:
```ruby
configure(parser: 'prism')
```

### 3.2 Example: AMS to Alba Migration Snippet

```ruby
# ams_to_alba.rb
Synvert::Rewriter.new 'ams_to_alba', 'Convert ActiveModelSerializers to Alba' do
  configure(parser: 'prism')

  within_files('app/serializers/**/*.rb') do
    # Class name conversion (XXXSerializer → XXXResource)
    with_node(type: 'class', name: /Serializer$/) do
      replace_with node.to_source.gsub(/(\w+)Serializer/, '\1Resource').gsub(/ < ActiveModel::Serializer/, ' < Alba::Resource')
    end

    # include conversion
    with_node(type: 'send', message: 'include', arguments: ['ActiveModel::Serializer']) do
      replace_with 'include Alba::Resource'
    end

    # attributes conversion
    with_node(type: 'send', message: 'attributes') do
      args = node.arguments.map(&:to_source)
      if args.length > 1
        new_code = args.map { |arg| "attribute #{arg}" }.join("\n  ")
        replace_with new_code
      else
        replace_with "attribute #{args.first}"
      end
    end

    # Association conversion
    with_node(type: 'send', message: ['has_many', 'has_one', 'belongs_to']) do
      relation_type = node.message
      name = node.arguments.first.to_source.delete(':')
      options = node.arguments[1..-1].map(&:to_source).join(', ')

      if %w[has_one belongs_to].include?(relation_type)
        if options.empty?
          replace_with "one :#{name}"
        else
          replace_with "one :#{name}, #{options}"
        end
      elsif relation_type == 'has_many'
        if options.empty?
          replace_with "many :#{name}"
        else
          replace_with "many :#{name}, #{options}"
        end
      end
    end

    # serialize method conversion
    with_node(type: 'send', message: 'serialize', arguments: { size: 2 }) do
      attribute_name = node.arguments[0].to_source
      serializer_name = node.arguments[1].to_source.gsub(/Serializer/, 'Resource')
      replace_with "attribute #{attribute_name}, resource: #{serializer_name}"
    end

    # Custom method conversion
    with_node(type: 'def') do
      method_name = node.name.to_s
      method_body = node.body.to_source
      if method_body.include?('object.')
        new_body = method_body.gsub(/object\./, 'resource.')
        replace_with <<~RUBY
          attribute :#{method_name} do |resource|
            #{new_body}
          end
        RUBY
      end
    end

    # Add require statement at the top
    goto_node(:root) do
      prepend "require 'alba'\n\n"
    end
  end
end
```

### 3.3 Indentation Helpers
- `add_leading_spaces` is **removed** as of v2.1.0. Use `indent` and `dedent` helpers for indentation adjustment.

---

## 4. Advanced Usage

### 4.1 Conditional Transformation
```ruby
with_node(type: 'send', message: 'attributes') do
  if node.arguments.length > 1
    args = node.arguments.map { |arg| "attribute #{arg.to_source}" }.join("\n  ")
    replace_with args
  else
    replace_with "attribute #{node.arguments.first.to_source}"
  end
end
```

### 4.2 Nested Node Processing
```ruby
with_node(type: 'class') do
  with_node(type: 'send', message: 'has_many') do
    relation_name = node.arguments.first.to_source.delete(':')
    replace_with "many :#{relation_name}"
  end
end
```

### 4.3 Adding and Removing Code
```ruby
with_node(type: 'class', name: /Resource$/) do
  append <<~RUBY
    def serializable_hash(options = nil)
      to_h
    end
  RUBY
end

with_node(type: 'def', name: 'active_model_serializer') do
  remove
end
```

### 4.4 Import and Require Conversion
```ruby
with_node(type: 'class', name: /Resource$/) do
  goto_node(:root) do
    prepend "require 'alba'\n"
  end
end
```

### 4.5 Custom Method Conversion
```ruby
with_node(type: 'def') do
  method_name = node.name.to_s
  method_body = node.body.to_source
  if method_body.include?('object.')
    new_body = method_body.gsub(/object\./, 'resource.')
    replace_with <<~RUBY
      attribute :#{method_name} do |resource|
        #{new_body}
      end
    RUBY
  end
end
```

---

## 5. File Discovery and Exclusion

- If you set `Configuration.respect_gitignore = true`, `.gitignore` will be respected when searching files.
- You can use `Configuration.only_paths` and `Configuration.skip_paths` to fine-tune which files are included or excluded.

---

## 6. Loading Snippets

- You can load snippets from local files, GitHub, or Gist using `Utils.eval_snippet`.
- If the snippet name is a URL, it will be automatically converted to a raw URL if needed.

---

## 7. CLI Options

```
Usage: synvert [options]
    -d, --dry-run                    Dry-run (no actual file changes)
    -s, --snippet SNIPPET            Path to custom snippet file
    -r, --run SNIPPET                Name of predefined snippet to run
    -l, --list                       List available snippets
    -o, --only ONLY                  Process only specific files (comma-separated)
    -p, --path PATH                  Path to process (default: current directory)
    -q, --query QUERY                Search for snippets by query
    -v, --version                    Show version
    -h, --help                       Show help message
```

---

## 8. AMS → Alba Main Migration Patterns

| ActiveModelSerializers | Alba |
|------------------------|------|
| `class UserSerializer < ActiveModel::Serializer` | `class UserResource` or `class UserResource < Alba::Resource` |
| `include ActiveModel::Serializer` | `include Alba::Resource` |
| `attributes :id, :name, :email` | `attribute :id` <br> `attribute :name` <br> `attribute :email` |
| `has_many :posts` | `many :posts` |
| `has_one :profile` | `one :profile` |
| `belongs_to :organization` | `one :organization` |
| `has_many :posts, serializer: PostSerializer` | `many :posts, resource: PostResource` |
| `serialize :metadata, MetadataSerializer` | `attribute :metadata, resource: MetadataResource` |
| `def full_name; "#{object.first_name} #{object.last_name}"; end` | `attribute :full_name do |resource|` <br> `  "#{resource.first_name} #{resource.last_name}"` <br> `end` |
| `root :user` | `key :user` |

---

## 9. Deprecated or Removed DSLs

- `add_leading_spaces` is **removed** as of v2.1.0. Use `indent`/`dedent` helpers instead.
- `save_data` / `load_data` DSLs are **removed** as of v2.2.0.
- `if_only_exist_node` DSL is **removed** as of v1.35.0.
- `redo_until_no_change` DSL is **removed** as of v1.31.1.

---

## 10. Other Notes

- Use `process_with_sandbox` to run a rewriter without changing files (for dry-run purposes).
- Use the `test` method to test a rewriter's effect.
- Always refer to the [official API reference](https://synvert-hq.github.io/synvert-core-ruby/Synvert/Core/Rewriter.html) and [CHANGELOG](https://github.com/synvert-hq/synvert-core-ruby/blob/main/CHANGELOG.md) for the latest information and breaking changes.
- Not all edge cases can be covered by automated transformation. Always review and test your code after migration.

---

## 11. References

- [Synvert Ruby Docs](https://synvert.net/ruby/docs/)
- [Synvert Core Ruby GitHub](https://github.com/synvert-hq/synvert-core-ruby)
- [Synvert Core Ruby Documentation](https://synvert-hq.github.io/synvert-core-ruby/Synvert/Core/Rewriter.html)
- [Synvert Architecture](https://synvert.net/architecture/)
- [Synvert Ruby Snippets](https://github.com/synvert-hq/synvert-snippets-ruby)
- [Rewriting Ruby with Synvert](https://thomasleecopeland.com/2016/11/17/rewriting-ruby-with-synvert.html)
- [Decimating Deprecated Finders with Synvert](https://thoughtbot.com/blog/decimating-deprecated-finders)
- [Alba Documentation](https://github.com/okuramasafumi/alba)
- [ActiveModelSerializers Documentation](https://github.com/rails-api/active_model_serializers)