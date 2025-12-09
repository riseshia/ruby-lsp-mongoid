# プロジェクト構造

```
ruby-lsp-mongoid/
├── lib/
│   ├── ruby_lsp/
│   │   ├── ruby_lsp_mongoid.rb          # Entry point, requires all components
│   │   └── ruby_lsp_mongoid/
│   │       ├── addon.rb                  # Add-on registration with Ruby LSP
│   │       ├── indexing_enhancement.rb   # DSL method indexing logic
│   │       └── hover.rb                  # Hover information provider
│   └── ruby_lsp_mongoid/
│       └── version.rb                    # Gem version constant
├── spec/
│   ├── spec_helper.rb                    # RSpec configuration
│   └── ruby_lsp_mongoid/
│       ├── indexing_enhancement_spec.rb  # Tests for DSL indexing
│       └── hover_spec.rb                 # Tests for hover functionality
├── sample/                               # Example Mongoid models for testing
├── bin/                                  # Development scripts (setup, console)
├── ruby-lsp-mongoid.gemspec              # Gem specification
├── Gemfile                               # Development dependencies
└── Rakefile                              # Rake tasks
```

## 主要コンポーネント

### `addon.rb`
Ruby LSPにアドオンを登録し、アクティベーション/非アクティベーションを処理し、リスナーインスタンスを作成します。

### `indexing_enhancement.rb`
Mongoid DSL呼び出し（`field`、`has_many`、`scope`など）をパースし、生成されたメソッドをRuby LSPのインデックスに登録します。以下を処理します：
- フィールドアクセサとエイリアス
- 関連メソッド（リーダー、ライター、ビルダー、`_ids`）
- スコープクラスメソッド
- コアMongoid::Documentメソッド

### `hover.rb`
DSLシンボルのホバー情報を提供します：
- フィールドオプション（型、デフォルト値、エイリアス）
- ファイルリンク付きの関連先クラス

## モジュール名前空間

- `RubyLsp::Mongoid` - すべてのアドオンコードのメイン名前空間
- `RubyLsp::Mongoid::VERSION` - バージョン定数
