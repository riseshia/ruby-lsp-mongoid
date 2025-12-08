## [Unreleased]

## [0.1.1] - 2025-12-08

### Added

- Auto-index `_id` and `id` accessor methods for all Mongoid models that use any DSL (field, associations, scope)
- Each class using Mongoid DSL now automatically gets `_id`, `_id=`, `id`, and `id=` methods indexed at the first DSL location

## [0.1.0] - 2025-12-02

- Initial release
