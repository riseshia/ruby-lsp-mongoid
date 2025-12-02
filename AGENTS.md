# Ruby LSP Mongoid - Agent Guidelines

## Project Overview

This is a Ruby LSP add-on that provides index enhancements for Mongoid DSL-generated methods. Similar to ruby-lsp-rails, it helps Ruby LSP understand dynamically generated methods from Mongoid models.

## TDD Development Workflow

This project follows strict Test-Driven Development (TDD) practices based on Kent Beck's principles.

### TDD Cycle: Red → Green → Refactor

1. **Red:** Write a failing test first
2. **Green:** Write minimal code to make the test pass
3. **Refactor:** Clean up code while keeping tests green
4. **Commit:** Only commit when all tests pass

### Code Quality Standards

- Eliminate duplication ruthlessly
- Express intent clearly through naming
- Keep methods small and focused
- Use the simplest solution that works
- Separate structural changes from behavioral changes

## Important Conventions

1. **Language:** **ALL code-related content MUST be written in English:**
   - Commit messages (both title and body)
   - Pull request titles and descriptions
   - Code comments
   - Variable names, function names, class names
   - Documentation and README updates
   - Test descriptions
   - Error messages and log output
   - **Exception:** You may communicate with the user in Korean for clarifications and discussions, but all artifacts (commits, PRs, code) must be in English

2. **Frozen String Literals:** All Ruby files use `# frozen_string_literal: true`

3. **Testing:** Uses RSpec for testing

4. **Naming:**
   - Module: `RubyLsp::Mongoid` (add-on namespace)
   - Gem: `ruby-lsp-mongoid`
   - Files follow Ruby conventions (snake_case)

## Before Making Changes

**Pre-Implementation Checklist:**

1. **Read relevant files in parallel** - Use multiple Read tool calls together
2. **Always run tests first:**
   ```bash
   bundle exec rspec
   ```

**Pre-Commit Checklist:**

1. **Run all tests** - Ensure nothing breaks
   ```bash
   bundle exec rspec
   ```
2. **Check for untracked files** - Add relevant new files
   ```bash
   git status
   ```
3. **Make ONE atomic commit** - Group all related changes together (code + new files)

## Commit Strategy

### Atomic Commits

**Always group related changes into single commits:**

✅ **Good** - Single commit:
```
"Add field DSL indexing support"
- Implement field declaration parsing
- Register generated accessor methods
- Add test cases
```

❌ **Bad** - Multiple commits:
```
"Add field DSL parsing"
"Add tests"
```