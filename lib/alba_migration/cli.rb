# frozen_string_literal: true

# rbs_inline: enabled

require "fileutils"
require "optparse"
require "alba_migration/snippet"

module AlbaMigration
  class CLI
    # @rbs arg: Array[String]
    # @rbs return: void
    def self.start(args)
      new.execute(args)
    end

    # @rbs args: Array[String]
    # @rbs return: void
    def execute(args = [])
      options = {}
      parser = options_parser(options)

      parser.parse!(args)
      file_patterns = args

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

      AlbaMigration::Snippet.process_snippets(migrate_file_path: matched_files, custom_snippet_path: options[:add_on])
    end

    private

    def options_parser(options)
      OptionParser.new do |opts|
        opts.banner = "Usage: alba_migration [options] FILES..."
        opts.on("--add_on FILE", "Specify a custom snippet Ruby file") do |file|
          options[:add_on] = file
        end
      end
    end
  end
end
