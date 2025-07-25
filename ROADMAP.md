# Hecate Roadmap

This document outlines the development roadmap for Hecate, a batteries-included language development toolkit for Crystal.

## Overview

Hecate aims to provide a complete toolkit for building programming languages and DSLs in Crystal, with first-class diagnostics, rapid prototyping capabilities, and IDE support. The project follows a modular architecture where each component is published as an independent shard.

## Release Milestones

### MVP (v0.1.0) ✅ **[CURRENT]**

**Status:** In Progress

- [x] **hecate-core**: Diagnostics system with multi-span support
  - [x] Source mapping and span tracking
  - [x] TTY renderer with colorized output
  - [x] Diagnostic builder API
  - [x] Test utilities (snapshot & golden file testing)
- [x] **hecate-lex**: Declarative lexer generation
  - [x] Token definition DSL
  - [x] Priority-based longest-match resolution
  - [x] Error recovery and diagnostics
  - [x] Nesting tracker for balanced delimiters
- [ ] **hecate-parse**: Parser combinators (Pratt)
  - [ ] Basic combinator library
  - [ ] Precedence handling
  - [ ] Error recovery strategies
- [ ] **hecate-ast**: AST node generation
  - [ ] Macro-based node definitions
  - [ ] Visitor pattern support
  - [ ] Pattern matching helpers
- [ ] **hecate-cli**: Basic CLI (build/run)
  - [ ] Project scaffolding (`hecate new`)
  - [ ] Build command with diagnostics
  - [ ] Run command for simple programs

### v0.2.0 - Semantic Analysis & Transpilation

- [ ] **hecate-sem**: Semantic analysis framework
  - [ ] Symbol table implementation
  - [ ] Scope management
  - [ ] Type environment
  - [ ] Basic type inference (Hindley-Milner lite)
- [ ] **Crystal Transpiler Backend**
  - [ ] IR → Crystal code generation
  - [ ] Source mapping preservation
  - [ ] Integration with Crystal compiler

### v0.3.0 - IDE Support

- [ ] **Tree-sitter Bridge**
  - [ ] Convert Tree-sitter nodes to Hecate AST
  - [ ] Incremental parsing support
  - [ ] Edit handling and diffing
- [ ] **LSP Server**
  - [ ] Basic protocol implementation
  - [ ] Real-time diagnostics
  - [ ] Document synchronization
  - [ ] Go-to-definition (stretch goal)

### v0.4.0 - IR & Optimization

- [ ] **hecate-ir**: Intermediate representation
  - [ ] SSA-based IR design
  - [ ] CFG construction
  - [ ] Phi node placement (Cytron algorithm)
- [ ] **Optimization Passes**
  - [ ] Constant folding
  - [ ] Dead code elimination
  - [ ] Basic inlining
- [ ] **REPL Support**
  - [ ] Interactive evaluation
  - [ ] Symbol table persistence
  - [ ] Fiber-based isolation

### v0.5.0 - LLVM Backend

- [ ] **hecate-codegen**: LLVM integration
  - [ ] IR → LLVM IR mapping
  - [ ] Crystal LibLLVM bindings usage
  - [ ] Object file generation
  - [ ] Basic optimizations

### v0.6.0 - WASM & Extensibility

- [ ] **WASM Backend**
  - [ ] IR → WAT emission
  - [ ] Binaryen integration (optional)
  - [ ] Browser runtime support
- [ ] **Plugin System**
  - [ ] Hook architecture
  - [ ] Custom pass registration
  - [ ] Language extension points

### v1.0.0 - Stable Release

- [ ] **API Stabilization**
  - [ ] Semantic versioning guarantees
  - [ ] Comprehensive documentation
  - [ ] Migration guides
- [ ] **Performance**
  - [ ] 100k+ tokens/sec lexing
  - [ ] Sub-second full project analysis
  - [ ] Instant incremental updates
- [ ] **Ecosystem**
  - [ ] Documentation site
  - [ ] Tutorial: "Build a language in 15 minutes"
  - [ ] Example languages repository

## Component Dependencies

```
hecate-cli
    ├── hecate-codegen
    │   └── hecate-ir
    │       └── hecate-sem
    │           └── hecate-ast
    │               └── hecate-parse
    │                   └── hecate-lex
    │                       └── hecate-core
    └── hecate-core (direct dependency for diagnostics)
```

## Development Principles

1. **Modular Architecture**: Each component is independently versioned and usable
2. **Diagnostics First**: Every phase produces high-quality error messages
3. **Performance Conscious**: Benchmarks guide optimization efforts
4. **IDE Ready**: Incremental processing and LSP support from early versions
5. **Documentation Driven**: Examples and tutorials accompany each release

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on how to contribute to Hecate.

## Version Policy

- Pre-1.0: Breaking changes allowed with minor version bumps
- Post-1.0: Strict semantic versioning
- Each shard maintains its own version and changelog
- Deprecation notices provided for at least one minor version

## Benchmarks & Goals

| Metric              | Target              | Current             |
| ------------------- | ------------------- | ------------------- |
| Lexing Speed        | 100k+ tokens/sec    | ~150k tokens/sec ✅ |
| Parse Time (1k LOC) | < 10ms              | TBD                 |
| Type Check (1k LOC) | < 50ms              | TBD                 |
| LSP Response        | < 100ms             | TBD                 |
| Memory Usage        | < 100MB for 10k LOC | TBD                 |

## Open Questions

- Macro-time diagnostics integration with Crystal compiler?
- Plugin system architecture (shard-based vs. dynamic)?
- How far to push type inference before 1.0?
- Stream processing for very large files?

---

_This roadmap is subject to change based on community feedback and development priorities._
