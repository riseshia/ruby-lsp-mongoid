## [Unreleased]

### Fixed

- Fix "can't add a new key into hash during iteration" error caused by concurrent hash modification when background signature update thread iterates while ruby-lsp modifies the index
- Fix compatibility with ruby-lsp 0.26.5+ by using `@listener.add_method` instead of directly calling `Entry::Method.new`

## [0.1.2] - 2025-12-15

### Added

- Auto-index core instance methods when including `Mongoid::Document` or `ApplicationDocument`:
  - ID accessors: `_id`, `_id=`, `id`, `id=` (always present in Mongoid documents)
  - Persistence methods: `save`, `save!`, `update`, `update!`, `destroy`, `delete`, `upsert`, `reload`
  - State methods: `new_record?`, `persisted?`, `valid?`, `changed?`
  - Attribute methods: `attributes`, `attributes=`, `assign_attributes`, `read_attribute`, `write_attribute`, `changes`, `errors`
  - Identity methods: `to_key`, `to_param`, `model_name`, `inspect`
- Auto-index core class methods when including `Mongoid::Document` or `ApplicationDocument`:
  - Query methods: `all`, `where`, `find`, `find_by`, `find_by!`, `first`, `last`, `count`, `exists?`, `distinct`
  - Creation methods: `create`, `create!`, `new`, `build`
  - Modification methods: `update_all`, `delete_all`, `destroy_all`
  - Database methods: `collection`, `database`
- Support for `ApplicationDocument` pattern (common Rails pattern where `ApplicationDocument` includes `Mongoid::Document`)

### Changed

- ID accessors (`_id`, `id`) are now indexed when including `Mongoid::Document`/`ApplicationDocument` instead of at the first DSL call
- Simplified internal implementation by removing `ensure_id_field_indexed` mechanism

## [0.1.1] - 2025-12-08

### Added

- Auto-index `_id` and `id` accessor methods for all Mongoid models that use any DSL (field, associations, scope)
- Each class using Mongoid DSL now automatically gets `_id`, `_id=`, `id`, and `id=` methods indexed at the first DSL location

## [0.1.0] - 2025-12-02

- Initial release
