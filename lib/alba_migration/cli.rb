# frozen_string_literal: true

module AlbaMigration
  class CLI
    def self.start(args)
      new.execute(args)
    end

    def execute(args)
      if args.empty? || args.include?("--help") || args.include?("-h")
        show_help
        exit(1) if args.empty?
        return
      end

      file_path = args[0]
      unless File.exist?(file_path)
        puts "Error: File '#{file_path}' not found"
        exit(1)
      end

      puts "Starting Alba migration for file '#{file_path}'..."
      # Implement actual migration process here
    end

    private

    def show_help
      puts <<~HELP
        Usage: alba_migration <file_name> [options]

        Options:
          -h, --help     Display this help message

        Description:
          Migrates the specified Ruby file to Alba format.
      HELP
    end
  end
end
