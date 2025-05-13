FROM ruby:3.3-slim

# Install required packages
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  git \
  libyaml-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and gemspec
COPY Gemfile* ../alba_migration.gemspec ./
COPY lib/alba_migration/version.rb ./lib/alba_migration/version.rb

# Install gems
RUN bundle install

# Copy application code
COPY . .

# Set default directory for command execution
WORKDIR /app

# Default command
CMD ["bash"] 