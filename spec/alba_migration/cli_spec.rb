# frozen_string_literal: true

RSpec.describe AlbaMigration::CLI do
  describe "#execute" do
    context "with fakefs", fakefs: true do
      let(:file_path) { "app/serializers/attributes_serializer.rb" }
      let(:test_content) { <<~EOS }
        class AttributesResource < ActiveModel::Serializer
          attributes :id, :name
        end
      EOS
      let(:test_rewritten_content) { <<~EOS }
        class AttributesResource
          include Alba::Resource
  
          attributes :id, :name
        end
      EOS
      let(:snippet_file) { "lib/alba_migration/snippets/convert_ams_to_alba.rb" }

      it "converts ActiveModelSerializers syntax to Alba syntax" do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, test_content)

        AlbaMigration::CLI.start([file_path])
        expect(File.read(file_path)).to eq(test_rewritten_content)
      end
    end

    context "when no files match the given pattern" do
      it "prints an error message and exits with status 1" do
        expect(Kernel).to receive(:exit).with(1)
        expect {
          AlbaMigration::CLI.start(["nonexistent_file.rb"])
        }.to output(/Error: No files matched the given pattern/).to_stdout
      end
    end
  end
end
