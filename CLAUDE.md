# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hecate is a language development toolkit for Crystal - a batteries-included set of shards for building new programming languages and DSLs. It provides components for lexing, parsing, AST manipulation, semantic analysis, IR generation, code generation, and IDE support.

## Architecture

### Monorepo Structure
```
hecate/
  docs/                    # Documentation
  shards/                  # Individual shards (components)
    hecate-core/          # Core diagnostics & utilities
    hecate-lex/           # Lexer generation
    hecate-parse/         # Parser (combinators + Tree-sitter)
    hecate-ast/           # AST node definitions
    hecate-sem/           # Semantic analysis
    hecate-ir/            # Intermediate representation
    hecate-codegen/       # Code generation backends
    hecate-cli/           # Command-line interface
  tools/                  # Build and release tools
    release.rb
    bench/
```

### Shard Dependencies
- All shards depend on `hecate-core` for diagnostics
- Dependencies flow downward only (no cycles)
- Each shard is independently versioned and published

#### Local Development Dependencies
For local development, internal shard dependencies should be declared in `shard.yml` using path references:

```yaml
# In shards/hecate-lex/shard.yml
dependencies:
  hecate-core:
    path: ../hecate-core
```

This allows you to require dependencies normally:
```crystal
# In specs or source files
require "hecate-core"
require "hecate-core/test_utils"  # Instead of relative paths
```

**Never use relative paths** like `require "../../hecate-core/src/..."` in specs or source. Always declare the dependency in shard.yml and require by shard name.

#### Test Utilities
For enhanced testing capabilities, require the test utils from hecate-core:
```crystal
# In spec files
require "./spec_helper"
require "hecate-core/test_utils"  # Provides snapshot testing, custom matchers, etc.
```

**Test Utils Structure**: Test utilities are exposed via `src/test_utils.cr` in hecate-core, which requires the internal test utilities and makes helper methods available.

## Key Commands

### Development Setup
```bash
# Install Crystal dependencies for a specific shard
cd shards/hecate-core
shards install

# Run tests for a specific shard
crystal spec

# Build and run examples
crystal build src/example.cr
./example
```

### Testing
```bash
# IMPORTANT: Always run the full test suite before committing changes
# This catches compilation errors and regressions across all shards

# Run all tests across all shards (REQUIRED before committing)
find shards -name "spec" -type d | while read dir; do
  echo "Testing $(dirname $dir)..."
  (cd $(dirname $dir) && crystal spec) || exit 1
done

# Verify compilation of all shards without running tests
find shards -name "src" -type d | while read dir; do
  echo "Checking compilation of $(dirname $dir)..."
  (cd $(dirname $dir) && crystal build --no-codegen src/**/*.cr) || exit 1
done

# Run tests for a specific shard during development
cd shards/<shard-name>
crystal spec

# Run specific test file
crystal spec spec/specific_spec.cr

# Run with verbose output
crystal spec --verbose
```

### Building
```bash
# Build a shard library
cd shards/<shard-name>
crystal build src/<shard-name>.cr

# Build with release optimizations
crystal build --release src/<shard-name>.cr
```

## Crystal Conventions for This Project

### Module Structure
- Top-level namespace: `Hecate`
- Sub-modules per shard: `Hecate::Core`, `Hecate::Lex`, etc.
- Version constant in each module: `VERSION = "x.y.z"`

### File Organization
**IMPORTANT**: Follow this exact directory structure for all shards:

```
shards/hecate-[name]/
  src/
    hecate-[name].cr          # Main entry point
    hecate/
      [name]/                 # Module files go here
        *.cr
  spec/
    hecate/
      [name]/                 # Specs mirror src structure
        *_spec.cr
    spec_helper.cr
```

Examples:
- `hecate-core/src/hecate/core/span.cr` → `module Hecate::Core`
- `hecate-lex/src/hecate/lex/lexer.cr` → `module Hecate::Lex`
- `hecate-parse/src/hecate/parse/parser.cr` → `module Hecate::Parse`

**Never create `src/hecate-[name]/`** - the directory under src should be `hecate/[name]/`

### Error Handling
- All phases return `{result, diagnostics : Array(Diagnostic)}`
- Use `Hecate::Core` diagnostics for all error reporting
- Never raise exceptions for user errors - always use diagnostics

### Testing Strategy
- Snapshot testing for diagnostic output
- Golden file testing for AST/IR representations
- Property-based testing for lexer/parser edge cases

## Key Design Patterns

### Diagnostic System (from hecate-core)
```crystal
# Create multi-span diagnostics with labels
diag = Hecate.error("unexpected token")
  .primary(span, "found here")
  .secondary(other_span, "while parsing this")
  .help("try adding a semicolon")
```

### Lexer DSL (hecate-lex)
```crystal
# Declarative token definitions
lexer = Hecate::Lex.define do
  token :WS, /\s+/, skip: true
  token :Ident, /[a-zA-Z_]\w*/
  token :Int, /\d+/
end
```

### AST Definitions (hecate-ast)
```crystal
# Macro-based AST node generation
Hecate::AST.define do
  node Add, left: Expr, right: Expr
  node IntLit, value: Int32
end
```

### Parser Combinators (hecate-parse)
```crystal
# Pratt-style expression parsing
rule :expr do
  infix :expr, :Plus, :term { |l, _, r| AST::Add.new(l, r) }
  alt :term
end
```

## Important Implementation Details

### Span Tracking
- Every token and AST node carries a `Span` for source mapping
- Spans are preserved through all compilation phases
- Use `SourceMap` for efficient line/column lookups

### Incremental Parsing
- Tree-sitter bridge is optional but enables IDE features
- Fallback to full reparse when Tree-sitter unavailable
- Always emit diagnostics incrementally for LSP

### Backend Architecture
- Start with Crystal transpiler (MVP)
- LLVM backend uses Crystal's LibLLVM bindings
- WASM backend planned for future

### Performance Considerations
- Lexer compiles to DFA for efficiency
- Use binary search for span→line/col conversion
- Cache symbol tables for REPL sessions

## Problem-Solving Approach

### When You Encounter Issues
1. **Don't guess or try random things** - Crystal has specific patterns and conventions
2. **Look up documentation first** using the resources in the "Crystal Documentation and Help" section
3. **Search for examples** in existing Crystal projects via GitHub
4. **Ask for help early** - The user has extensive Crystal experience and can provide quick solutions

### Common Crystal Gotchas
- Macro expansion errors: Check Crystal docs for macro syntax
- Type inference issues: Look for explicit type annotations in similar code
- Shard dependency conflicts: Check version compatibility in shard.yml files
- Compilation errors in specs: Often due to missing require statements

## Development Workflow

### Adding a New Shard
1. Create directory structure: `shards/<name>/`
2. Add shard.yml with proper dependencies
3. Create src/ and spec/ directories
4. Update monorepo shard.yml to include path dependency
5. Add to CI matrix

### Making Changes
1. Work in the specific shard directory
2. Add tests for all new functionality BEFORE implementation
3. Run tests for the specific shard during development
4. **Run the full test suite across ALL shards before committing**
   - This catches compilation errors in dependent shards
   - Ensures no regressions were introduced
5. Update version if API changes
6. Document public APIs with Crystal doc comments

**Testing Workflow:**
```bash
# 1. Add new test cases first
cd shards/hecate-core
crystal spec spec/new_feature_spec.cr  # Should fail

# 2. Implement the feature
# ... make your changes ...

# 3. Verify local tests pass
crystal spec  # All tests in current shard

# 4. CRITICAL: Run full test suite
cd ../..  # Back to project root
find shards -name "spec" -type d | while read dir; do
  (cd $(dirname $dir) && crystal spec) || exit 1
done
```

### Release Process
- Automated via `tools/release.rb`
- Subtree mirrors pushed to `hecatecr/<shard-name>`
- Version bumps triggered by release commits

## Crystal Documentation and Help

### Looking Up Crystal APIs
When encountering Crystal internals or API questions, use these resources in order:

1. **Crystal API Documentation** - Direct URL pattern:
   ```
   https://crystal-lang.org/api/1.17.1/Namespace.html
   ```
   Examples:
   - `Comparable`: https://crystal-lang.org/api/1.17.1/Comparable.html
   - `HTTP::Server`: https://crystal-lang.org/api/1.17.1/HTTP/Server.html
   - `JSON::Any::Type`: https://crystal-lang.org/api/1.17.1/JSON/Any/Type.html

2. **MCP Servers** for deeper research:
   - Use `mcp__context7` for Crystal library documentation
   - Use `mcp__deepwiki` for comprehensive Crystal examples
   - Search GitHub via MCP for real-world code examples

3. **Ask for Help** - The user (watzon) has 8+ years of Crystal experience. If you're stuck after trying documentation, ask directly rather than guessing.

## Common Pitfalls

### Crystal-Specific
- No `.to_sym` method - use enums instead
- Symbols are for macros, not runtime values
- Use enums for type-safe constants
- **No top-level instance variable definitions** - Always use `getter`, `setter`, or `property` macros instead of `@var = value` at the class level
  - Use `private getter/setter/property` for internal state
  - Example: Instead of `@items = [] of String`, use `private getter items = [] of String`
  - This applies to all instance variables - they should be declared using macros, not direct assignment

### Architecture
- Never create circular dependencies between shards
- Always return diagnostics, don't raise exceptions
- Preserve source spans through all transformations

### Testing
- **Always run the full test suite** - partial tests miss compilation errors
- Write tests BEFORE implementation (TDD approach)
- Use snapshot tests for complex output
- Test error cases as thoroughly as success cases
- Keep integration tests in hecate-cli
- Watch for compilation errors in dependent shards when changing APIs

## Future Considerations

### Planned Features
- Macro-time diagnostics integration
- Plugin system for extensibility
- Advanced type inference (HM-style)
- Streaming parser for large files

### Performance Goals
- 100k+ tokens/sec lexing
- Sub-second full project analysis
- Instant incremental updates

### API Stability
- Pre-1.0: Expect breaking changes
- Post-1.0: Semantic versioning guarantees
- Deprecation cycle for major changes