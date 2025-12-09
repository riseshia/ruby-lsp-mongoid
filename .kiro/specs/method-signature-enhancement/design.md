# 設計ドキュメント: メソッドシグネチャ強化

## 概要

この機能は、Ruby LSP Mongoidアドオンのインデックス強化機能を改善し、Mongoid DSLから生成されるメソッドに対して正確なシグネチャ情報を提供します。現在の実装では、ほとんどのメソッドが空のシグネチャで登録されており、IDEでパラメータヒントが適切に表示されません。

主な改善点：
1. DSL生成メソッド（field、association、scope）の正確なパラメータシグネチャ
2. コアMongoid::Documentメソッドの実際のシグネチャ反映（インデックスから取得）
3. ホバー情報へのシグネチャ表示

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                         Addon                                │
├─────────────────────────────────────────────────────────────┤
│  activate()                                                  │
│    └─> Thread: wait_for_indexing_and_update_signatures()    │
│          │                                                   │
│          ├─ Wait: index.initial_indexing_completed          │
│          │                                                   │
│          └─ update_mongoid_signatures(index)                │
│               ├─ Find Mongoid models in index               │
│               ├─ Resolve signatures from Mongoid modules    │
│               └─ Update method entry signatures             │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ includes
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   SignatureResolver                          │
├─────────────────────────────────────────────────────────────┤
│  INSTANCE_METHOD_SOURCES = [                                 │
│    "Mongoid::Persistable::Savable",                         │
│    "Mongoid::Persistable::Updatable", ...                   │
│  ]                                                           │
│                                                              │
│  resolve_instance_method_signature(index, method_name)      │
│  resolve_class_method_signature(index, method_name)         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  IndexingEnhancement                         │
├─────────────────────────────────────────────────────────────┤
│  on_call_node_enter                                          │
│    ├─ handle_include (空のシグネチャでcoreメソッドを登録)    │
│    ├─ handle_field (reader/writerシグネチャ)                 │
│    ├─ handle_*_association (associationシグネチャ)           │
│    └─ handle_scope (lambdaパラメータ抽出)                    │
│                                                              │
│  * コアメソッドは空のシグネチャで登録                        │
│  * Addonでインデックス完了後にシグネチャを更新               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      HoverProvider                           │
├─────────────────────────────────────────────────────────────┤
│  - Display method signature from index entry                 │
│  - Format parameters with names and types                    │
│  - Show field options alongside signature                    │
└─────────────────────────────────────────────────────────────┘
```

## コンポーネントとインターフェース

### 遅延シグネチャ取得戦略

Ruby LSPのインデックス順序は保証されていません。プロジェクトファイルがMongoid gemより先にインデックス化される可能性があります。そのため、**遅延評価（Lazy Evaluation）**方式を使用します。

**設計決定：**
1. **インデックス時点**: 空のシグネチャでメソッドを登録（現在の動作を維持）
2. **インデックス完了後**: `index.initial_indexing_completed`を待機した後、Mongoidインデックスからシグネチャを取得して更新

**実装方式：**
- `Addon#activate`で別スレッドを開始
- スレッドで`index.initial_indexing_completed`をポーリング
- インデックス完了後、登録されたMongoidメソッドのシグネチャをMongoidモジュールから取得して更新

**利点：**
- Mongoidバージョンに応じて自動的に正しいシグネチャを提供
- ハードコードされたシグネチャのメンテナンスが不要
- Ruby LSPの既存インデックスインフラを活用

**欠点：**
- インデックス完了前は空のシグネチャで表示される（短時間）

### 1. SignatureResolverモジュール

Ruby LSPインデックスからMongoidメソッドのシグネチャを取得するモジュールです。

```ruby
module RubyLsp
  module Mongoid
    module SignatureResolver
      INSTANCE_METHOD_SOURCES = [
        "Mongoid::Persistable::Savable",
        "Mongoid::Persistable::Updatable", 
        "Mongoid::Persistable::Deletable",
        "Mongoid::Persistable::Destroyable",
        "Mongoid::Attributes",
        "Mongoid::Reloadable",
        "Mongoid::Stateful",
        "Mongoid::Changeable",
      ].freeze

      CLASS_METHOD_SOURCES = [
        "Mongoid::Findable",
        "Mongoid::Criteria",
        "Mongoid::Persistable::Creatable::ClassMethods",
      ].freeze

      def resolve_instance_method_signature(index, method_name)
        INSTANCE_METHOD_SOURCES.each do |module_name|
          entries = index.resolve_method(method_name, module_name)
          next unless entries&.any?
          
          entry = entries.first
          return entry.signatures if entry.respond_to?(:signatures) && entry.signatures.any?
        end
        
        nil
      end

      def resolve_class_method_signature(index, method_name)
        CLASS_METHOD_SOURCES.each do |module_name|
          entries = index.resolve_method(method_name, module_name)
          next unless entries&.any?
          
          entry = entries.first
          return entry.signatures if entry.respond_to?(:signatures) && entry.signatures.any?
        end
        
        nil
      end
    end
  end
end
```

### 2. コアメソッドレジストリ

シグネチャを取得するメソッドのリストを定義します。

```ruby
CORE_INSTANCE_METHODS = %w[
  save save! update update! destroy delete upsert reload
  new_record? persisted? valid? changed?
  attributes attributes= assign_attributes read_attribute write_attribute
  changes errors to_key to_param model_name inspect
].freeze

CORE_CLASS_METHODS = %w[
  all where find find_by find_by! first last count exists? distinct
  create create! new build update_all delete_all destroy_all
  collection database
].freeze
```

### 3. DSLメソッドシグネチャ

各DSLタイプ別のメソッドシグネチャ生成ロジックです。DSL生成メソッドはパターンが固定されているため、直接定義します。

```ruby
# Field DSL
def add_accessor_methods(name, location, comments: nil)
  reader_signatures = [RubyIndexer::Entry::Signature.new([])]
  @listener.add_method(name.to_s, location, reader_signatures, comments: comments)

  writer_signatures = [
    RubyIndexer::Entry::Signature.new([
      RubyIndexer::Entry::RequiredParameter.new(name: :value)
    ])
  ]
  @listener.add_method("#{name}=", location, writer_signatures, comments: comments)
end

# Builder methods (build_*, create_*, create_*!)
def add_builder_methods(name, location)
  builder_signatures = [
    RubyIndexer::Entry::Signature.new([
      RubyIndexer::Entry::OptionalParameter.new(name: :attributes)
    ])
  ]
  @listener.add_method("build_#{name}", location, builder_signatures)
  @listener.add_method("create_#{name}", location, builder_signatures)
  @listener.add_method("create_#{name}!", location, builder_signatures)
end

# Scope DSL - lambdaパラメータ抽出
def extract_lambda_parameters(lambda_node)
  return [] unless lambda_node.is_a?(Prism::LambdaNode)
  
  params_node = lambda_node.parameters
  return [] unless params_node
  
  params = []
  
  params_node.requireds&.each do |param|
    params << RubyIndexer::Entry::RequiredParameter.new(name: param.name)
  end
  
  params_node.optionals&.each do |param|
    params << RubyIndexer::Entry::OptionalParameter.new(name: param.name)
  end
  
  if params_node.rest
    name = params_node.rest.name || :args
    params << RubyIndexer::Entry::RestParameter.new(name: name)
  end
  
  params_node.keywords&.each do |param|
    if param.value
      params << RubyIndexer::Entry::OptionalKeywordParameter.new(name: param.name)
    else
      params << RubyIndexer::Entry::RequiredKeywordParameter.new(name: param.name)
    end
  end
  
  params
end
```

### 4. 更新されたAddon

Addonクラスでインデックス完了後にシグネチャを更新するロジックを追加します。

```ruby
class Addon < ::RubyLsp::Addon
  include SignatureResolver

  def activate(global_state, outgoing_queue)
    @global_state = global_state
    @outgoing_queue = outgoing_queue
    
    Thread.new { wait_for_indexing_and_update_signatures }
  end

  private

  def wait_for_indexing_and_update_signatures
    index = @global_state.index
    
    sleep(0.1) until index.initial_indexing_completed
    
    update_mongoid_signatures(index)
  end

  def update_mongoid_signatures(index)
    CORE_INSTANCE_METHODS.each do |method_name|
      mongoid_signatures = resolve_instance_method_signature(index, method_name)
      next unless mongoid_signatures
      
      update_method_signatures(index, method_name, mongoid_signatures)
    end
    
    CORE_CLASS_METHODS.each do |method_name|
      mongoid_signatures = resolve_class_method_signature(index, method_name)
      next unless mongoid_signatures
      
      update_singleton_method_signatures(index, method_name, mongoid_signatures)
    end
  end
end
```

### 5. 更新されたHoverProvider

シグネチャ情報をホバーに表示するロジックです。

```ruby
class Hover
  def format_signature(entry)
    return nil unless entry.respond_to?(:signatures) && entry.signatures.any?
    
    sig = entry.signatures.first
    params = sig.parameters.map { |param| format_parameter(param) }.join(", ")
    
    "(#{params})"
  end
  
  def format_parameter(param)
    case param
    when RubyIndexer::Entry::RequiredParameter
      param.name.to_s
    when RubyIndexer::Entry::OptionalParameter
      "#{param.name} = nil"
    when RubyIndexer::Entry::RequiredKeywordParameter
      "#{param.name}:"
    when RubyIndexer::Entry::OptionalKeywordParameter
      "#{param.name}: nil"
    when RubyIndexer::Entry::RestParameter
      "*#{param.name}"
    when RubyIndexer::Entry::KeywordRestParameter
      "**#{param.name}"
    when RubyIndexer::Entry::BlockParameter
      "&#{param.name}"
    end
  end
end
```

## データモデル

### Entry::Signature

Ruby LSPの既存シグネチャモデルを活用します。

```ruby
# RubyIndexer::Entry::Signature
# - parameters: Array<Parameter>

# Parameter Types (RubyIndexer::Entry::*)
# - RequiredParameter(name:)
# - OptionalParameter(name:)
# - RequiredKeywordParameter(name:)
# - OptionalKeywordParameter(name:)
# - RestParameter(name:)
# - KeywordRestParameter(name:)
# - BlockParameter(name:)
```

## 正確性プロパティ

### プロパティ1: Field DSLシグネチャの一貫性

*任意の*フィールド名でfield DSLを呼び出す場合、生成されたreaderメソッドは空のパラメータシグネチャを持ち、writerメソッドは正確に1つの必須パラメータを持つ必要があります。

**検証: 要件1.1**

### プロパティ2: Many Association DSLシグネチャの一貫性

*任意の*アソシエーション名でhas_manyまたはhas_and_belongs_to_many DSLを呼び出す場合、生成されたコレクションreaderは空のパラメータを、writerは1つの必須パラメータを、_ids readerは空のパラメータを、_ids writerは1つの必須パラメータを持つ必要があります。

**検証: 要件1.2**

### プロパティ3: Singular Association DSLシグネチャの一貫性

*任意の*アソシエーション名でhas_one、belongs_to、またはembeds_one DSLを呼び出す場合、生成されたreaderは空のパラメータを、writerは1つの必須パラメータを、builderメソッドは1つのオプショナルパラメータを持つ必要があります。

**検証: 要件1.3**

### プロパティ4: Scope DSLパラメータ抽出の一貫性

*任意の*scope DSL呼び出しでlambdaがパラメータを持つ場合、生成されたクラスメソッドのシグネチャはlambdaのパラメータと同じ構造を持つ必要があります。

**検証: 要件1.4**

### プロパティ5: コアインスタンスメソッドシグネチャの同期

*任意の*CORE_INSTANCE_METHODSに定義されたメソッドについて、インデックス完了後、そのメソッドのシグネチャはMongoidモジュールから取得したシグネチャと一致する必要があります。

**検証: 要件2.1、2.2、2.3**

### プロパティ6: コアクラスメソッドシグネチャの同期

*任意の*CORE_CLASS_METHODSに定義されたメソッドについて、インデックス完了後、そのメソッドのシグネチャはMongoidモジュールから取得したシグネチャと一致する必要があります。

**検証: 要件3.1、3.2、3.3**

### プロパティ7: DSL位置の正確性

*任意の*DSL呼び出しから生成されたすべてのメソッドは、そのDSL呼び出しの正確な行番号をlocationとして持つ必要があり、同じDSLから生成されたすべてのメソッドは同じlocationを共有する必要があります。

**検証: 要件4.1、4.2、4.3**

### プロパティ8: ホバーシグネチャ表示

*任意の*シグネチャを持つメソッドエントリについて、ホバー出力はそのシグネチャのパラメータ情報を含む必要があります。

**検証: 要件5.1**

### プロパティ9: フィールドホバーオプション表示

*任意の*field DSLでtype、default、またはaliasオプションが指定されている場合、そのフィールドアクセサのホバー出力は指定されたすべてのオプションを含む必要があります。

**検証: 要件5.2**

### プロパティ10: アソシエーションホバークラス表示

*任意の*association DSL呼び出しについて、ホバー出力はターゲットクラス名を含む必要があります。

**検証: 要件5.3**

## エラーハンドリング

### インデックス完了待機

- インデックスが完了していない場合はポーリングで待機
- タイムアウトなしで完了まで待機（Ruby LSPは常に完了する）

### シグネチャ取得失敗

- Mongoidモジュールでメソッドが見つからない場合は空のシグネチャを維持
- エラー発生時はログ出力後に処理を継続

### Lambdaパラメータ抽出失敗

- scopeのlambdaがパース不可能な場合は空のシグネチャで登録
- 複雑なデフォルト値は無視され、パラメータ名のみ抽出

## テスト戦略

### ユニットテスト

- SignatureResolverモジュールのシグネチャ取得テスト
- DSLメソッドシグネチャ生成テスト
- ホバー出力フォーマットテスト

### 統合テスト

- インデックス完了後のシグネチャ更新テスト
- Mongoidモジュールからの実際のシグネチャ取得テスト
