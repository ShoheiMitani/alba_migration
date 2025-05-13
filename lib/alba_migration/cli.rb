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
        puts "エラー: ファイル '#{file_path}' が見つかりません"
        exit(1)
      end

      puts "ファイル '#{file_path}' のAlba移行を開始します..."
      # ここに実際の移行処理を実装
    end

    private

    def show_help
      puts <<~HELP
        使用方法: alba_migration <ファイル名> [オプション]

        オプション:
          -h, --help     このヘルプメッセージを表示します

        説明:
          指定されたRubyファイルをAlbaフォーマットに移行します。
      HELP
    end
  end
end
