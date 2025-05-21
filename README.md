# AlbaMigration

## What is AlbaMigration?
AlbaMigration is a Ruby gem that helps you migrate your Ruby code from [ActiveModelSerializers (AMS)](https://github.com/rails-api/active_model_serializers) to [Alba](https://github.com/okuramasafumi/alba) syntax automatically. It provides a command-line tool to convert AMS serializer classes to Alba resource classes, making your migration process easier and less error-prone.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "alba_migration"
```

And then execute:

```bash
bundle install
```

## Usage

### Command Line Tool

After installing the gem, you can use the CLI to migrate your Ruby files:

```bash
alba_migration path/to/your/serializer.rb
```

You can also use glob patterns to migrate multiple files at once:

```bash
alba_migration app/serializers/**/*.rb
```

If you are using Bundler:

```bash
bundle exec alba_migration app/serializers/**/*.rb
```

#### Custom Snippet Support (`--add_on` option)

You can specify a custom snippet Ruby file to extend or override the default migration behavior using the `--add_on` option:

```bash
alba_migration --add_on path/to/custom_snippet.rb path/to/your/serializer.rb
```

- The custom snippet file should define a Synvert rewriter object.
- This allows you to add your own migration logic in addition to the built-in conversion.

#### Example

**Before:**
```ruby
class AttributesResource < ActiveModel::Serializer
  attributes :id, :name
end
```

**After:**
```ruby
class AttributesResource
  include Alba::Resource

  attributes :id, :name
end
```

### Error Handling
- If no files match the given pattern, an error message will be shown and the process will exit with status 1.

## Supported Syntax
Currently, AlbaMigration supports the following AMS syntax:
- `class ... < ActiveModel::Serializer` with `attributes ...` inside the class body
- Only the conversion of the class definition and `attributes` is supported at this time
- Attribute methods (e.g. `attribute :foo do ... end`) are now automatically converted
- Other AMS features (e.g., associations, custom methods) are **not** yet supported

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/ShoheiMitani/alba_migration](https://github.com/ShoheiMitani/alba_migration).

To get started with development:

1. Clone the repository
2. Run `bin/setup` to install dependencies
3. Run tests with `bin/rspec spec/`
4. Check/fix code style with `bin/standardrb --fix`

If you find a bug, please [open an issue](https://github.com/ShoheiMitani/alba_migration/issues) with detailed steps to reproduce it.

## License

This project is licensed under the MIT License. See [LICENSE.txt](LICENSE.txt) for details.

## Code of Conduct

Everyone interacting in the AlbaMigration project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
