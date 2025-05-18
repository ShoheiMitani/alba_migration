# frozen_string_literal: true

require "fileutils"
require "synvert"

module AlbaMigration
  class CLI
    def self.start(_args)
      new.execute
    end

    def execute
      dest_dir = Synvert::Command.default_snippets_home
      snippets_dir = File.expand_path(File.join(__dir__, "snippets"))

      FileUtils.mkdir_p(dest_dir)
      Dir.glob(File.join(snippets_dir, "*")).each do |snippet|
        FileUtils.cp(snippet, dest_dir)
      end
    end
  end
end
