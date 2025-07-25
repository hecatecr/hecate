# hecate-core

Core diagnostics and utilities for the Hecate language development toolkit.

## Features

- 🎯 **Beautiful diagnostics** - Rust-style error messages with multi-span support
- 📍 **Source mapping** - Efficient tracking of source files and positions
- 🔍 **Span tracking** - Precise location information for all language elements
- 🎨 **Flexible rendering** - TTY and JSON output formats for different use cases
- 🧪 **Testing utilities** - Snapshot testing and custom matchers for language tools
- 🚀 **Zero dependencies** - Lightweight foundation for language tools

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  hecate-core:
    github: hecatecr/hecate-core
    version: ~> 0.1.0
```

Then run `shards install`

## Quick Start

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

## API Reference

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

# Query diagnostic properties
diag.error?        # => true
diag.severity      # => Severity::Error
diag.message       # => "type mismatch"
diag.label_count   # => 2
diag.has_help?     # => true
```

### Source Management

Manage source files with `SourceMap`:

```crystal
source_map = Hecate::SourceMap.new

# Add source files
file_id = source_map.add_file("path/to/file.cr", "source code")
virtual_id = source_map.add_virtual("<repl>", "1 + 2")  # For REPL/generated code

# Retrieve source files
source_file = source_map.get(file_id)
source_file = source_map.get_by_path("path/to/file.cr")

# Convert spans to line/column positions
position = source_map.span_to_position(span)
puts "Error at #{position.display_line}:#{position.display_column}"

# Query source map
source_map.has_file?("path/to/file.cr")  # => true
source_map.size                           # => 2
source_map.each_source { |id, file| }     # Iterate all sources
```

Work with individual source files:

```crystal
source = source_map.get(file_id)

# Convert between byte offsets and positions
position = source.byte_to_position(10)      # Byte offset to line/column
byte_offset = source.position_to_byte(position)  # Line/column to byte offset

# Extract source lines
line = source.line_at(1)                    # Get specific line (0-based)
lines = source.line_range(0, 2)            # Get range of lines
```

### Spans and Positions

Track locations in source code:

```crystal
# Create spans (immutable)
span = Hecate::Span.new(file_id, start_byte, end_byte)
span = Hecate::Span.new(file_id, start_byte, length: 10)  # Alternative

# Span operations
span.contains?(other_span)  # Check if span contains another
span.overlaps?(other_span)  # Check if spans overlap
merged = span.merge(other)  # Merge two spans

# Span properties
span.source_id   # File ID
span.start_byte  # Start offset
span.end_byte    # End offset
span.length      # Byte length

# Positions (0-based internally, 1-based for display)
pos = Hecate::Position.new(line: 5, column: 10)
pos.line           # => 5 (0-based)
pos.column         # => 10 (0-based)
pos.display_line   # => 6 (1-based for humans)
pos.display_column # => 11 (1-based for humans)
```

### Rendering

Output diagnostics in different formats:

#### TTY Renderer (Terminal)

```crystal
renderer = Hecate::TTYRenderer.new(output: STDOUT, width: 80)

# Emit single diagnostic
renderer.emit(diagnostic, source_map)

# Works with builders too
renderer.emit(diagnostic_builder, source_map)
```

#### JSON Renderer (LSP-compatible)

```crystal
# Emit single diagnostic
Hecate::Core::Renderer::JSON.emit(diagnostic, io)
json_string = Hecate::Core::Renderer::JSON.emit_string(diagnostic)

# Batch operations
Hecate::Core::Renderer::JSON.emit_batch(diagnostics, io)
Hecate::Core::Renderer::JSON.emit_by_severity(diagnostics, :error, io)
Hecate::Core::Renderer::JSON.emit_by_source(diagnostics, io)

# LSP format for language servers
Hecate::Core::Renderer::JSON.emit_lsp_publish_diagnostics(diagnostics, io)
```

### Testing Utilities

Enhanced testing support for language tools:

```crystal
require "hecate-core/test_utils"

# Snapshot testing
Snapshot.match("test_name", actual_output)
Snapshot.match_formatted("test_name", actual)  # Normalizes whitespace
Snapshot.match_yaml("test_name", data)         # YAML format
Snapshot.match_json("test_name", data)         # JSON format

# Golden file testing
GoldenFile.test("lexer/tokens", actual_tokens)

# Test generators
identifier = Generators.identifier(10)          # Random valid identifier
code = Generators.source_snippet(5)            # Sample code snippet
span = Generators.span(file_id, max_offset)   # Random valid span

# Custom matchers for specs
diagnostic.should have_error("message")
diagnostic.should have_warning("message").at(span)
span.should match_span(start: 10, length: 5)

# Helper methods
source_map = create_test_source("code")
span = span(0, 10)  # Quick span creation
pos = pos(5, 10)    # Quick position creation
```

## Development

```bash
# Run tests
crystal spec

# Build
crystal build src/hecate-core.cr

# Generate docs
crystal docs
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`crystal spec`)
5. Commit your changes (`git commit -am 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Create a Pull Request

## License

MIT - see [LICENSE](LICENSE) for details