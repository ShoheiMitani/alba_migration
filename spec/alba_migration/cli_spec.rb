# frozen_string_literal: true

RSpec.describe AlbaMigration::CLI do
  let(:cli) { described_class.new }

  describe "#execute" do
    context "引数がない場合" do
      it "ヘルプメッセージを表示してエラー終了すること" do
        expect { cli.execute([]) }.to output(/使用方法/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "--helpオプションが指定された場合" do
      it "ヘルプメッセージを表示して正常終了すること" do
        expect { cli.execute(["--help"]) }.to output(/使用方法/).to_stdout
        # SystemExitが発生しないことを別途確認
        expect { cli.execute(["--help"]) }.not_to raise_error
      end
    end

    context "存在しないファイルが指定された場合" do
      it "エラーメッセージを表示してエラー終了すること" do
        expect { cli.execute(["non_existent_file.rb"]) }.to output(/エラー: ファイル/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "存在するファイルが指定された場合" do
      before do
        allow(File).to receive(:exist?).with("test.rb").and_return(true)
      end

      it "移行処理のメッセージを表示すること" do
        expect { cli.execute(["test.rb"]) }.to output(/のAlba移行を開始します/).to_stdout
      end
    end
  end
end
