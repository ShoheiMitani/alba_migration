# frozen_string_literal: true

RSpec.describe AlbaMigration::CLI do
  let(:cli) { described_class.new }

  describe "#execute" do
    context "when no arguments are provided" do
      it "displays help message and exits with error" do
        expect { cli.execute([]) }.to output(/Usage/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when --help option is specified" do
      it "displays help message and exits normally" do
        expect { cli.execute(["--help"]) }.to output(/Usage/).to_stdout
        # Verify that SystemExit is not raised
        expect { cli.execute(["--help"]) }.not_to raise_error
      end
    end

    context "when a non-existent file is specified" do
      it "displays error message and exits with error" do
        expect { cli.execute(["non_existent_file.rb"]) }.to output(/Error: File/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when an existing file is specified" do
      before do
        allow(File).to receive(:exist?).with("test.rb").and_return(true)
      end

      it "displays migration process message" do
        expect { cli.execute(["test.rb"]) }.to output(/Starting Alba migration/).to_stdout
      end
    end
  end
end
