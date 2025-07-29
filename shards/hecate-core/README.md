# hecate-core

Core diagnostics and utilities for the Hecate language toolkit.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
- [API](#api)
  - [Diagnostics](#diagnostics)
  - [Source Management](#source-management)
  - [Spans and Positions](#spans-and-positions)
  - [Rendering](#rendering)
  - [Testing Utilities](#testing-utilities)
- [Contributing](#contributing)
- [License](#license)

## Install

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  hecate-core:
    github: hecatecr/hecate-core
    version: ~> 0.1.0
```

Then run `shards install`

## Usage

```crystal
require "hecate-core"

# Create a source map
source_map = Hecate::SourceMap.new
file_id = source_map.add_file("example.hec", "let x = 42\nlet y = x + 1")

# Create spans pointing to specific code
x_span = Hecate::Span.new(file_id, 4, 5)    # Points to 'x' in line 1
y_span = Hecate::Span.new(file_id, 16, 17)  # Points to 'x' in line 2

# Create a diagnostic with multiple labels
diag = Hecate.error("undefined variable 'x'")
  .primary(y_span, "not found in this scope")
  .secondary(x_span, "did you mean this 'x'?")
  .help("variables must be in scope to be used")

# Render the diagnostic
renderer = Hecate::TTYRenderer.new
renderer.emit(diag, source_map)
```

## API

### Diagnostics

Create diagnostics using the fluent builder API:

```crystal
# Factory methods for different severity levels
diag = Hecate.error("message")      # Error diagnostic
diag = Hecate.warning("message")    # Warning diagnostic
diag = Hecate.info("message")       # Informational diagnostic
diag = Hecate.hint("message")       # Hint diagnostic

# Add labels to point to specific code locations
diag = Hecate.error("type mismatch")
  .primary(span, "expected String")      # Primary label (main error location)
  .secondary(other_span, "found Int32")  # Secondary label (related location)
  .help("try converting with .to_s")     # Helpful suggestion
  .note("type inference happens here")   # Additional note
```

### Source Management

Manage source files with `SourceMap`:

```crystal
source_map = Hecate::SourceMap.new

# Add source files
file_id = source_map.add_file("path/to/file.cr", "source code")
virtual_id = source_map.add_virtual("<repl>", "1 + 2")  # For REPL/generated code

# Convert spans to line/column positions
position = source_map.span_to_position(span)
puts "Error at #{position.display_line}:#{position.display_column}"
```

### Spans and Positions

Track locations in source code:

```crystal
# Create spans (immutable)
span = Hecate::Span.new(file_id, start_byte, end_byte)

# Span operations
span.contains?(other_span)  # Check if span contains another
span.overlaps?(other_span)  # Check if spans overlap
merged = span.merge(other)  # Merge two spans
```

### Rendering

Output diagnostics in different formats:

```crystal
# TTY Renderer (Terminal)
renderer = Hecate::Core::TTYRenderer.new(output: STDOUT, width: 80)
renderer.emit(diagnostic, source_map)

# JSON Renderer (LSP-compatible)
json_renderer = Hecate::Core::Renderer::JSON.new(source_map)
json_string = json_renderer.emit_string(diagnostic)

# Batch operations
json_renderer.emit_batch(diagnostics, io)
json_renderer.emit_by_severity(diagnostics, :error, io)
json_renderer.emit_lsp_publish_diagnostics(diagnostics, io)
```

### Testing Utilities

Enhanced testing support for language tools:

```crystal
require "hecate-core/test_utils"

# Snapshot testing
Snapshot.match("test_name", actual_output)

# Golden file testing
GoldenFile.test("lexer/tokens", actual_tokens)

# Test generators
identifier = Generators.identifier(10)  # Random valid identifier
```

For complete API documentation, see the [Crystal docs](https://hecatecr.github.io/hecate-core).

## Contributing

This repository is a read-only mirror. All development happens in the [Hecate monorepo](https://github.com/hecatecr/hecate).

- **Issues**: Please file issues in the [main repository](https://github.com/hecatecr/hecate/issues)
- **Pull Requests**: Submit PRs to the [monorepo](https://github.com/hecatecr/hecate)
- **Questions**: Open a discussion in the [monorepo discussions](https://github.com/hecatecr/hecate/discussions)

## License

MIT © Chris Watson. See [LICENSE](LICENSE) for details.