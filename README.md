# Hecate

[![CI](https://github.com/hecatecr/hecate/workflows/CI/badge.svg)](https://github.com/hecatecr/hecate/actions)
[![Crystal Version](https://img.shields.io/badge/crystal-latest-brightgreen)](https://crystal-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A batteries-included language development toolkit for Crystal. Build your own programming languages and DSLs with first-class diagnostics, incremental parsing, and IDE support.

## Features

- 🎯 **First-class diagnostics** - Beautiful, Rust-style error messages with multi-span support
- ⚡ **Rapid prototyping** - Generate lexers, parsers, and ASTs in minutes with declarative DSLs
- 🔧 **Modular architecture** - Pick and choose components for your language
- 📝 **IDE-ready** - LSP server support and incremental parsing (coming soon)
- 🚀 **Multiple backends** - Transpile to Crystal, LLVM, or WASM (roadmap)

## Project Structure

Hecate is organized as a monorepo with independently versioned shards:

```
hecate/
├── shards/
│   ├── hecate-core/    # Diagnostics, source mapping, and utilities
│   ├── hecate-lex/     # Lexer generation and tokenization
│   ├── hecate-parse/   # Parser combinators and Tree-sitter bridge
│   ├── hecate-ast/     # AST node definitions and visitors
│   ├── hecate-sem/     # Semantic analysis and type checking
│   ├── hecate-ir/      # Intermediate representation
│   ├── hecate-codegen/ # Code generation backends
│   └── hecate-cli/     # Command-line interface
├── docs/               # Documentation
└── tools/              # Build and release tooling
```

## Quick Start

### Using individual shards

Add the shards you need to your `shard.yml`:

```yaml
dependencies:
  hecate-core:
    github: hecatecr/hecate-core
    version: ~> 0.1.0
  hecate-lex:
    github: hecatecr/hecate-lex
    version: ~> 0.1.0
```

### Example: Building a simple expression language

```crystal
require "hecate-core"
require "hecate-lex"

# Define your lexer
MyLexer = Hecate::Lex.define do
  token :WS, /\s+/, skip: true
  token :Int, /\d+/
  token :Plus, /\+/
  token :Minus, /-/
  token :EOF
end

# Create a source file
source_map = Hecate::SourceMap.new
file_id = source_map.add_file("example.expr", "42 + 13")

# Lex the input
tokens, diagnostics = MyLexer.lex(file_id, source_map)

# Handle any errors
if diagnostics.any?
  renderer = Hecate::TTYRenderer.new
  diagnostics.each { |diag| renderer.emit(diag, source_map) }
end
```

## Development

### Prerequisites

- Crystal 1.17.0 or higher
- Git

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/hecatecr/hecate.git
   cd hecate
   ```

2. Install dependencies:
   ```bash
   shards install
   ```

3. Run tests for a specific shard:
   ```bash
   cd shards/hecate-core
   crystal spec
   ```

### Running all tests

```bash
find shards -name "spec" -type d | while read dir; do
  echo "Testing $(dirname $dir)..."
  (cd $(dirname $dir) && crystal spec) || exit 1
done
```

## Roadmap

- [x] Core diagnostics system
- [x] Basic lexer generation
- [ ] Parser combinators
- [ ] AST framework
- [ ] Semantic analysis
- [ ] Crystal transpiler
- [ ] LSP server
- [ ] LLVM backend
- [ ] WASM backend

See the [full roadmap](docs/ROADMAP.md) for more details.

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting PRs.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Inspired by:
- Rust's `codespan-reporting` for beautiful diagnostics
- `logos` for fast lexer generation
- The Crystal compiler's excellent architecture