# frozen_string_literal: true

RSpec.describe AlbaMigration::CLI do
  describe "#execute", fakefs: true do
    let(:dest_dir) { "tmp/synvert_snippets" }

    before do
      # creates dummy file for FakeFS
      snippets_dir = File.expand_path(File.join(__dir__, "../../lib/alba_migration/snippets"))
      FileUtils.mkdir_p(snippets_dir)
      File.write(File.join(snippets_dir, "dummy1.rb"), "# test snippet")
      File.write(File.join(snippets_dir, "dummy2.rb"), "# test snippet")

      allow(Synvert::Command).to receive(:default_snippets_home).and_return(dest_dir)

      FileUtils.mkdir_p(dest_dir)
    end

    it "copies all snippet files to the Synvert snippets home" do
      described_class.new.execute
      expect(File).to exist(File.join(dest_dir, "dummy1.rb"))
      expect(File).to exist(File.join(dest_dir, "dummy2.rb"))
    end
  end
end
