# frozen_string_literal: true

RSpec.describe AlbaMigration do
  it "has a version number" do
    expect(AlbaMigration::VERSION).not_to be nil
  end
end
