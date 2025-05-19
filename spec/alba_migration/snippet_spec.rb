# frozen_string_literal: true

require "spec_helper"
require "alba_migration/snippet"

RSpec.describe "ActiveModelSerializers to Alba syntax conversion" do
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

  context "with fakefs", fakefs: true do
    it "converts ActiveModelSerializers syntax to Alba syntax" do
      rewriter = AlbaMigration::Snippet.create(migrate_file_path: file_path)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, test_content)

      rewriter.process
      expect(File.read(file_path)).to eq(test_rewritten_content)
    end
  end
end
