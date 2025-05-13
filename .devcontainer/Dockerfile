FROM ruby:3.3-slim

# 必要なパッケージをインストール
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  git \
  libyaml-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリの設定
WORKDIR /app

# Gemfileとgemspecをコピー
COPY Gemfile* ../alba_migration.gemspec ./
COPY lib/alba_migration/version.rb ./lib/alba_migration/version.rb

# Gemのインストール
RUN bundle install

# アプリケーションコードをコピー
COPY . .

# コマンド実行時のデフォルトディレクトリ
WORKDIR /app

# デフォルトのコマンド
CMD ["bash"] 