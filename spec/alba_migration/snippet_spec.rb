# frozen_string_literal: true

require "spec_helper"
require "alba_migration/snippet"
require "tmpdir"
require "pathname"

RSpec.describe "ActiveModelSerializers to Alba syntax conversion" do
  let(:file_path) { "app/serializers/attributes_serializer.rb" }
  let(:test_content) { <<~EOS }
    class AttributeResource < ActiveModel::Serializer
      attribute :birthday
      attribute :age
      attribute(:gender)
      attribute :user_first_name
      attribute(:object) { 'access_token' }
      attribute(:user_id) { object.user_id }
      def user_first_name
        object.user.first_name
      end
      def dummy_method
        "dummy"
      end
    end
  EOS
  let(:test_rewritten_content) { <<~EOS }
    class AttributeResource
      include Alba::Resource

      attributes :birthday, :age, :gender

      attribute :object do
        "access_token"
      end
      attribute :user_id do |object|
        object.user_id
      end
      attribute :user_first_name do |object|
        object.user.first_name
      end
      def dummy_method
        "dummy"
      end
    end
  EOS

  it "converts ActiveModelSerializers syntax to Alba syntax" do
    Dir.mktmpdir do |tmpdir|
      tmp_file_path = File.join(tmpdir, file_path)
      FileUtils.mkdir_p(File.dirname(tmp_file_path))
      File.write(tmp_file_path, test_content)

      Dir.chdir(tmpdir) do
        relative_file_path = Pathname.new(tmp_file_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
        AlbaMigration::Snippet.process_snippets(migrate_file_path: relative_file_path)
        expect(File.read(tmp_file_path)).to eq(test_rewritten_content)
      end
    end
  end
end
