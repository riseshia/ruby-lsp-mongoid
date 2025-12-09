# 技術スタック

## 言語とランタイム

- Ruby 3.3+
- Gemベースの配布

## コア依存関係

- `ruby-lsp` (~> 0.22) - IDE統合のためのRuby LSPフレームワーク
- `mongoid` (~> 9.0) - MongoDB ODM（開発/テスト依存関係）

## 開発ツール

- Bundler - 依存関係管理
- RSpec - テストフレームワーク
- Rake - タスクランナー

## 一般的なコマンド

```bash
# 依存関係のインストール
bundle install

# すべてのテストを実行
bundle exec rspec

# 特定のテストファイルを実行
bundle exec rspec spec/ruby_lsp_mongoid/indexing_enhancement_spec.rb

# Gemをビルド
bundle exec rake build

# Gemをローカルにインストール
bundle exec rake install

# 対話型コンソール
bin/console
```

## Ruby LSPアドオンインターフェース

このプロジェクトはRuby LSPアドオンインターフェースを実装しています：
- `RubyLsp::Addon` - アドオン登録のための基底クラス
- `RubyIndexer::Enhancement` - DSL生成メソッドのインデックス化用
- `RubyLsp::Requests::Support::Common` - ホバー/補完サポート用

## コードスタイル要件

- すべてのRubyファイルには `# frozen_string_literal: true` を含める必要があります
- すべてのコード成果物（コメント、名前、コミット）は英語で記述する必要があります
