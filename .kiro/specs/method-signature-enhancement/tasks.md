# Implementation Tasks

## Task 1: Add SignatureResolver module

- [x] Create `lib/ruby_lsp/ruby_lsp_mongoid/signature_resolver.rb`
- [x] Define `INSTANCE_METHOD_SOURCES` constant with Mongoid module names
- [x] Define `CLASS_METHOD_SOURCES` constant with Mongoid module names
- [x] Implement `resolve_instance_method_signature(index, method_name)` method
- [x] Implement `resolve_class_method_signature(index, method_name)` method
- [x] Add unit tests for SignatureResolver module

## Task 2: Update Addon to perform deferred signature update

- [x] Include SignatureResolver module in Addon class
- [x] Add `wait_for_indexing_and_update_signatures` method that runs in a separate thread
- [x] Implement waiting for `index.initial_indexing_completed`
- [x] Implement `update_mongoid_signatures(index)` to update registered method signatures
- [x] Add tests verifying signature update after indexing completion (requires integration test setup)

## Task 3: Update IndexingEnhancement for DSL method signatures

- [x] Update `add_accessor_methods` to use proper writer signature with required parameter
- [x] Update `add_builder_methods` to use optional attributes parameter
- [x] Implement `extract_lambda_parameters(lambda_node)` for scope DSL
- [x] Update `handle_scope` to extract and use lambda parameters
- [x] Add tests for DSL method signatures

## Task 4: Update HoverProvider to display signatures

- [x] Implement `format_signature(entry)` method
- [x] Implement `format_parameter(param)` for each parameter type
- [x] Update hover output to include signature information
- [x] Add tests for hover signature display

## Task 5: Add comprehensive signature tests

- [x] Add tests for field reader/writer signatures
- [x] Add tests for association signatures (has_many, has_one, belongs_to, etc.)
- [x] Add tests for scope signatures with lambda parameters
- [x] Add tests for core method signature updates from Mongoid modules (requires integration test)
- [x] Add tests for location accuracy (existing tests cover this)
