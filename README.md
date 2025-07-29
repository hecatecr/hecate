<p align="center">
  <img src="https://github.com/hecatecr/hecate/raw/refs/heads/main/assets/logo.png" width="300" />
</p>

# hecate

[![CI](https://github.com/hecatecr/hecate/workflows/CI/badge.svg)](https://github.com/hecatecr/hecate/actions)
[![Crystal Version](https://img.shields.io/badge/crystal-latest-brightgreen)](https://crystal-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A batteries-included language development toolkit for Crystal.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [Quick Example](#quick-example)
  - [Available Shards](#available-shards)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Install

Add the shards you need to your `shard.yml`:

```yaml
dependencies:
  hecate-core:
    github: hecatecr/hecate-core
    version: ~> 0.1.0
  hecate-lex:
    github: hecatecr/hecate-lex
    version: ~> 0.1.0
  hecate-ast:
    github: hecatecr/hecate-ast
    version: ~> 0.1.0
```

Run `shards install`.

## Usage

### Quick Example

Build a simple expression lexer:

```crystal
require "hecate-core"
require "hecate-lex"

# Define your lexer
lexer = Hecate::Lex.define do |ctx|
  ctx.token :WS, /\s+/, skip: true
  ctx.token :INT, /\d+/
  ctx.token :PLUS, /\+/
  ctx.token :MINUS, /-/
  ctx.token :MULTIPLY, /\*/
  ctx.token :DIVIDE, /\//
end

# Create a source file
source_map = Hecate::Core::SourceMap.new
source_id = source_map.add_file("example.expr", "42 + 13 * 2")
source_file = source_map.get(source_id).not_nil!

# Lex the input
tokens, diagnostics = lexer.scan(source_file)

# Handle any errors
if diagnostics.any?
  renderer = Hecate::Core::TTYRenderer.new
  diagnostics.each { |diag| renderer.emit(diag, source_map) }
else
  # Process tokens
  tokens.each do |token|
    puts "#{token.kind}: '#{token.lexeme(source_file)}'"
  end
end
```

### Available Shards

Hecate is organized as a monorepo with independently versioned shards:

- **[hecate-core](shards/hecate-core)** - Diagnostics, source mapping, and utilities
- **[hecate-ast](shards/hecate-ast)** - AST node definitions and visitor pattern
- **[hecate-lex](shards/hecate-lex)** - Lexer generation with declarative DSL
- **[hecate-parse](shards/hecate-parse)** - Parser combinators and Tree-sitter bridge (coming soon)
- **[hecate-sem](shards/hecate-sem)** - Semantic analysis and type checking (coming soon)
- **[hecate-ir](shards/hecate-ir)** - Intermediate representation (coming soon)
- **[hecate-codegen](shards/hecate-codegen)** - Code generation backends (coming soon)
- **[hecate-cli](shards/hecate-cli)** - Command-line interface (coming soon)

## Development

### Prerequisites

- Crystal 1.17.0 or higher
- Git
- Just (optional, for convenience commands)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/hecatecr/hecate.git
   cd hecate
   ```

2. Install dependencies:
   ```bash
   just install
   # or manually: SHARDS_OVERRIDE=shard.dev.yml shards install
   ```

3. Run all tests:
   ```bash
   just test
   ```

4. Run tests for a specific shard:
   ```bash
   just test-shard core
   just test-shard lex
   just test-shard ast
   ```

### Development Workflow

The monorepo uses a dual shard configuration:
- **Production shards** (`shards/*/shard.yml`) - Point to GitHub repositories
- **Development shards** (`shard.dev.yml`) - Use local path dependencies

All development commands should be run from the repository root using the justfile or with `SHARDS_OVERRIDE=shard.dev.yml`.

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Issues and PRs** should be filed against this monorepo, not individual shard repositories
2. **All development** happens in the monorepo - individual shard repos are read-only mirrors
3. **Tests are required** - Write tests before implementation (TDD approach)
4. **Run the full test suite** before committing to catch cross-shard compilation errors
5. **Follow Crystal conventions** and the patterns established in the codebase

See our [Contributing Guide](CONTRIBUTING.md) for detailed information.

## License

MIT © Chris Watson. See [LICENSE](LICENSE) for details.