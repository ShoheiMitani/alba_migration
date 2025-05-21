# frozen_string_literal: true

# rbs_inline: enabled

require_relative "snippet/superclass_rewritable"
require_relative "snippet/attribute_rewritable"

module AlbaMigration
  class Snippet
    include SuperclassRewritable
    include AttributeRewritable

    # @rbs migrate_file_path: String
    # @rbs return: Array[Synvert::Core::Rewriter]
    def self.snippets(migrate_file_path:)
      snippet_creator = new(migrate_file_path:)
      [
        snippet_creator.superclass_rewriter,
        snippet_creator.attribute_method_rewriter
      ]
    end

    # @rbs migrate_file_path: String
    # @rbs custom_snippet_path: String | nil
    # @rbs return: void
    def self.process_snippets(migrate_file_path:, custom_snippet_path: nil)
      snippets = snippets(migrate_file_path:)
      if custom_snippet_path
        custom_snippet = eval(File.read(custom_snippet_path)) # rubocop:disable Security/Eval
        snippets.push(custom_snippet)
      end
      snippets.each(&:process)
    end

    # @rbs migrate_file_path: String
    # @rbs return: void
    def initialize(migrate_file_path:)
      @migrate_file_path = migrate_file_path
    end
  end
end
