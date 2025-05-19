# frozen_string_literal: true

require "spec_helper"
require "alba_migration/snippet"
require "tmpdir"
require "pathname"

RSpec.describe "ActiveModelSerializers to Alba syntax conversion" do
  context "simple class" do
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
          relative_file_path = Pathname.new(tmp_file_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
          rewriter = AlbaMigration::Snippet.new(migrate_file_path: relative_file_path).superclass_rewriter
          rewriter.process
          expect(File.read(tmp_file_path)).to eq(test_rewritten_content)
        end
      end
    end
  end

  context "nested class" do
    context "simple class" do
      let(:file_path) { "app/serializers/attributes_serializer.rb" }
      let(:test_content) { <<~EOS }
        module Api
          class AttributesResource < ActiveModel::Serializer
            attributes :id, :name
          end
        end
      EOS
      let(:test_rewritten_content) { <<~EOS }
        module Api
          class AttributesResource
            include Alba::Resource
    
            attributes :id, :name
          end
        end
      EOS
      let(:snippet_file) { "lib/alba_migration/snippets/convert_ams_to_alba.rb" }

      it "converts ActiveModelSerializers syntax to Alba syntax" do
        Dir.mktmpdir do |tmpdir|
          tmp_file_path = File.join(tmpdir, file_path)
          FileUtils.mkdir_p(File.dirname(tmp_file_path))
          File.write(tmp_file_path, test_content)

          Dir.chdir(tmpdir) do
            relative_file_path = Pathname.new(tmp_file_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
            rewriter = AlbaMigration::Snippet.new(migrate_file_path: relative_file_path).superclass_rewriter
            rewriter.process
            expect(File.read(tmp_file_path)).to eq(test_rewritten_content)
          end
        end
      end
    end
  end
end
