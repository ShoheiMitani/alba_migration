# frozen_string_literal: true

require "spec_helper"
require "alba_migration/snippet"
require "tmpdir"
require "pathname"

RSpec.describe AlbaMigration::Snippet do
  context "#if_rewriter" do
    shared_examples "converts" do
      let(:file_path) { "app/serializers/attributes_serializer.rb" }

      it "converts ActiveModelSerializers syntax to Alba syntax" do
        Dir.mktmpdir do |tmpdir|
          tmp_file_path = File.join(tmpdir, file_path)
          FileUtils.mkdir_p(File.dirname(tmp_file_path))
          File.write(tmp_file_path, test_content)

          Dir.chdir(tmpdir) do
            relative_file_path = Pathname.new(tmp_file_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
            rewriter = AlbaMigration::Snippet.new(migrate_file_path: relative_file_path).if_rewriter
            rewriter.process
            expect(File.read(tmp_file_path)).to eq(test_rewritten_content)
          end
        end
      end
    end

    context "attributes" do
      it_behaves_like "converts" do
        let(:test_content) { <<~EOS }
          class AttributesResource
            attributes :id, if: -> { true }
          end
        EOS
        let(:test_rewritten_content) { <<~EOS }
          class AttributesResource
            attributes :id, if: proc { true }
          end
        EOS
      end
    end

    context "attribute" do
      it_behaves_like "converts" do
        let(:test_content) { <<~EOS }
          class AttributesResource
            attribute :id, if: -> { true }
          end
        EOS
        let(:test_rewritten_content) { <<~EOS }
          class AttributesResource
            attributes :id, if: proc { true }
          end
        EOS
      end
    end
  end
end
