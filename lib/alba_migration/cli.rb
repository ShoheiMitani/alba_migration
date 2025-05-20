# frozen_string_literal: true

# rbs_inline: enabled

require "fileutils"
require "alba_migration/snippet"

module AlbaMigration
  class CLI
    # @rbs arg: Array[String]
    # @rbs return: void
    def self.start(args)
      new.execute(args)
    end

    # @rbs file_patterns: Array[String]
    # @rbs return: void
    def execute(file_patterns = [])
      matched_files = file_patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq
      if matched_files.empty?
        puts "Error: No files matched the given pattern(s): #{file_patterns.join(", ")}"
        exit(1)
      end

      missing_patterns = file_patterns.select { |pattern| Dir.glob(pattern).empty? }
      unless missing_patterns.empty?
        puts "Error: No files found for pattern(s): #{missing_patterns.join(", ")}"
        exit(1)
      end

      AlbaMigration::Snippet.process_snippets(migrate_file_path: matched_files)
    end
  end
end
