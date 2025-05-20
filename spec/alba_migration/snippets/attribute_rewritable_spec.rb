# frozen_string_literal: true

require "spec_helper"
require "alba_migration/snippet"
require "tmpdir"
require "pathname"

RSpec.describe AlbaMigration::Snippet do
  describe "#attribute_method_rewriter" do
    shared_examples "converts" do
      let(:file_path) { "app/serializers/attributes_serializer.rb" }

      it "converts ActiveModelSerializers syntax to Alba syntax" do
        Dir.mktmpdir do |tmpdir|
          tmp_file_path = File.join(tmpdir, file_path)
          FileUtils.mkdir_p(File.dirname(tmp_file_path))
          File.write(tmp_file_path, test_content)

          Dir.chdir(tmpdir) do
            relative_file_path = Pathname.new(tmp_file_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
            rewriter = AlbaMigration::Snippet.new(migrate_file_path: relative_file_path).attribute_method_rewriter
            rewriter.process
            expect(File.read(tmp_file_path)).to eq(test_rewritten_content)
          end
        end
      end
    end

    context "attributes" do
      context "attribute" do
        it_behaves_like "converts" do
          let(:test_content) { <<~EOS }
            class AttributeResource
              attribute :account_id
              attribute(:user_id)
            end
          EOS
          let(:test_rewritten_content) { <<~EOS }
            class AttributeResource
              attributes :account_id, :user_id
            end
          EOS
        end
      end

      context "%i[]" do
        it_behaves_like "converts" do
          let(:test_content) { <<~EOS }
            class AttributeResource
              attributes %i[
                account_id
                user_id
              ]
            end
          EOS
          let(:test_rewritten_content) { <<~EOS }
            class AttributeResource
              attributes :account_id, :user_id
            end
          EOS
        end
      end
    end

    context "attribute" do
      let(:test_content) { <<~EOS }
        class AttributeResource
          attribute(:object) { 'access_token' }
          attribute(:user_id) { object.user_id }
        end
      EOS
      let(:test_rewritten_content) { <<~EOS }
        class AttributeResource
          attribute :object do
            "access_token"
          end
          attribute :user_id do |object|
            object.user_id
          end
        end
      EOS
    end

    context "original method" do
      context "when attribute detail is implemented in def method" do
        it_behaves_like "converts" do
          let(:test_content) { <<~EOS }
            class AttributeResource
              attribute :account_id
              attribute :user_id
  
              def account_id
                object.account_id
              end
            end
          EOS
          let(:test_rewritten_content) { <<~EOS }
            class AttributeResource
              attributes :user_id

              attribute :account_id do |object|
                object.account_id
              end
            end
          EOS
        end
      end

      context "when attributes detail is implemented in def method" do
        it_behaves_like "converts" do
          let(:test_content) { <<~EOS }
            class AttributeResource
              attributes :account_id, :user_id

              def account_id
                object.account_id
              end
            end
          EOS
          let(:test_rewritten_content) { <<~EOS }
            class AttributeResource
              attributes :user_id

              attribute :account_id do |object|
                object.account_id
              end
            end
          EOS
        end
      end

      context "independent def method" do
        it_behaves_like "converts" do
          let(:test_content) { <<~EOS }
            class AttributeResource
              def account_id
                "1"
              end
            end
          EOS
          let(:test_rewritten_content) { <<~EOS }
            class AttributeResource
              def account_id
                "1"
              end
            end
          EOS
        end
      end

      context "independent def method but execute object method in block" do
        it_behaves_like "converts" do
          let(:test_content) { <<~EOS }
            class AttributeResource
              def account_id
                object.account_id
              end
            end
          EOS
          let(:test_rewritten_content) { <<~EOS }
            class AttributeResource
              attribute :account_id do |object|
                object.account_id
              end
            end
          EOS
        end

        it_behaves_like "converts" do
          let(:test_content) { <<~EOS }
            class AttributeResource
              def accounts
                [
                  {
                    id: object.account_id
                  }
                ]
              end
            end
          EOS
          let(:test_rewritten_content) { <<~EOS }
            class AttributeResource
              attribute :accounts do |object|
                [
                  {
                    id: object.account_id
                  }
                ]
              end
            end
          EOS
        end
      end
    end

    context "super class" do
      it_behaves_like "converts" do
        let(:test_content) { <<~EOS }
          class AttributeResource < ParentResource
            attribute :birthday
            attribute(:gender)
          end
        EOS
        let(:test_rewritten_content) { <<~EOS }
          class AttributeResource < ParentResource
            attributes :birthday, :gender
          end
        EOS
      end
    end

    context "combined attribute and independent method" do
      it_behaves_like "converts" do
        let(:test_content) { <<~EOS }
          class AttributeResource < ParentResource
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
          class AttributeResource < ParentResource
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
      end
    end
  end
end
