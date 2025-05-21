# frozen_string_literal: true

require "tmpdir"
require "pathname"
require "alba_migration/cli"

RSpec.describe AlbaMigration::CLI do
  describe "#execute" do
    let(:file_path) { "app/serializers/attributes_serializer.rb" }
    let(:test_content) { <<~EOS }
      class AttributesResource < ActiveModel::Serializer
        attributes :id, :name
      end
    EOS
    let(:snippet_file) { "lib/alba_migration/snippets/convert_ams_to_alba.rb" }

    context "without add_on" do
      let(:test_rewritten_content) { <<~EOS }
        class AttributesResource
          include Alba::Resource
    
          attributes :id, :name
        end
      EOS

      it "converts ActiveModelSerializers syntax to Alba syntax" do
        Dir.mktmpdir do |tmpdir|
          tmp_file_path = File.join(tmpdir, file_path)
          FileUtils.mkdir_p(File.dirname(tmp_file_path))
          File.write(tmp_file_path, test_content)

          Dir.chdir(tmpdir) do
            AlbaMigration::CLI.start([file_path])
            expect(File.read(tmp_file_path)).to eq(test_rewritten_content)
          end
        end
      end
    end

    context "with add_on" do
      let(:test_rewritten_content) { <<~EOS }
        class CustomAttributesResource
          include Alba::Resource
    
          attributes :id, :name
        end
      EOS

      it "outputs add_on file name and requires it when --add_on is given" do
        Dir.mktmpdir do |tmpdir|
          tmp_file_path = File.join(tmpdir, file_path)
          FileUtils.mkdir_p(File.dirname(tmp_file_path))
          File.write(tmp_file_path, test_content)

          custom_snippet_path = File.expand_path("../../spec/fixtures/custom_snippet.rb", __dir__)
          expect(AlbaMigration::Snippet).to receive(:process_snippets)
            .with(migrate_file_path: [file_path], custom_snippet_path: custom_snippet_path)
            .and_call_original

          Dir.chdir(tmpdir) do
            AlbaMigration::CLI.start(["--add_on", custom_snippet_path, file_path])
            expect(File.read(tmp_file_path)).to eq(test_rewritten_content)
          end
        end
      end
    end
  end
end
