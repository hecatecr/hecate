# hecate-core

Core diagnostics and utilities for the Hecate language development toolkit.

## Features

- 🎯 **Beautiful diagnostics** - Rust-style error messages with multi-span support
- 📍 **Source mapping** - Efficient tracking of source files and positions
- 🔍 **Span tracking** - Precise location information for all language elements
- 🎨 **Flexible rendering** - TTY and JSON output formats for different use cases
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

## Usage

```crystal
require "hecate-core"

# Create a source map
source_map = Hecate::SourceMap.new
file_id = source_map.add_file("example.hec", "let x = 42")

# Create a span
span = Hecate::Span.new(file_id, 4, 5)  # Points to 'x'

# Create a diagnostic
diag = Hecate.error("undefined variable")
  .primary(span, "not found in this scope")
  .help("did you mean to declare it first?")

# Render the diagnostic
renderer = Hecate::TTYRenderer.new
renderer.emit(diag, source_map)
```

## Components

- **SourceMap** - Registry for managing multiple source files
- **Span** - Represents a range in source code
- **Position** - Line and column information
- **Diagnostic** - Error/warning messages with contextual information
- **Renderers** - TTY and JSON output formatters

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