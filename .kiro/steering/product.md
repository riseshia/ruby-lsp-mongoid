# プロダクト概要

Ruby LSP Mongoidは、Mongoidアプリケーションのためのエディタ機能を強化するRuby LSPアドオンです。

## 目的

ruby-lsp-railsがRailsで動作するのと同様に、Ruby LSPがMongoid DSLから動的に生成されるメソッドを理解できるようにします。

## 主な機能

- **定義へジャンプ**: メソッド呼び出しからDSL宣言へジャンプ
- **オートコンプリート**: 補完候補に生成されたメソッドを表示
- **ホバー情報**: フィールドオプション、型、関連先クラスをクリック可能なリンクと共に表示

## サポートされているMongoid DSL

- `field` - 型、エイリアス、デフォルト値オプション付きのフィールドアクセサ
- `has_many`, `has_one`, `belongs_to`, `has_and_belongs_to_many` - 関連
- `embeds_many`, `embeds_one`, `embedded_in` - 埋め込みドキュメント
- `scope` - クラスメソッドとしての名前付きスコープ
- `include Mongoid::Document` / `ApplicationDocument` - コアインスタンスメソッドとクラスメソッド

## 対象ユーザー

動的に生成されるメソッドに対するIDEレベルのサポートを必要とする、Mongoid ODMを使用しているRuby開発者。
