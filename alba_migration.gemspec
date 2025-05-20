# frozen_string_literal: true

require_relative "lib/alba_migration/version"

Gem::Specification.new do |spec|
  spec.name = "alba_migration"
  spec.version = AlbaMigration::VERSION
  spec.authors = ["ShoheiMitani"]
  spec.email = ["mitani49@gmail.com"]

  spec.summary = "Migrate ActiveModelSerializers (AMS) code to Alba syntax automatically."
  spec.description = "AlbaMigration is a CLI tool and library to help you convert your Ruby code from ActiveModelSerializers (AMS) to Alba syntax. It rewrites AMS serializer classes to Alba resource classes, supporting the migration of class definitions and attributes."
  spec.homepage = "https://github.com/ShoheiMitani/alba_migration"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ShoheiMitani/alba_migration"
  spec.metadata["changelog_uri"] = "https://github.com/ShoheiMitani/alba_migration/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = ["alba_migration"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "synvert-core"
  spec.add_runtime_dependency "standard"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
