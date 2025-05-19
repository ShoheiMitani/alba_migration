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
    let(:test_rewritten_content) { <<~EOS }
      class AttributesResource
        include Alba::Resource
  
        attributes :id, :name
      end
    EOS
    let(:snippet_file) { "lib/alba_migration/snippets/convert_ams_to_alba.rb" }

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
end
