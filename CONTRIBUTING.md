# Contributing to Hecate

Thank you for your interest in contributing to Hecate! This document provides guidelines and instructions for contributing to the project.

## Development Setup

1. **Prerequisites**
   - Crystal 1.17.0 or higher
   - Git

2. **Clone the repository**
   ```bash
   git clone https://github.com/hecatecr/hecate.git
   cd hecate
   ```

3. **Install dependencies**
   ```bash
   shards install
   ```

## Code Style Guidelines

- Follow Crystal's standard formatting conventions
- Use `crystal tool format` before committing
- Write descriptive commit messages
- Keep methods small and focused
- Add documentation comments for public APIs

## Testing Requirements

- Write specs for all new functionality
- Ensure all tests pass before submitting PR
- Run tests for individual shards:
  ```bash
  cd shards/hecate-core
  crystal spec
  ```
- Run the full test suite:
  ```bash
  find shards -name "spec" -type d | while read dir; do
    echo "Testing $(dirname $dir)..."
    (cd $(dirname $dir) && crystal spec) || exit 1
  done
  ```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and ensure they pass
5. Format your code (`crystal tool format`)
6. Commit your changes with a descriptive message
7. Push to your fork
8. Open a Pull Request with a clear description

## Monorepo Structure

Hecate uses a monorepo structure with individual shards:
- Each shard is independently versioned
- Changes to a shard should be made in its directory
- Dependencies between shards must flow downward only

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include Crystal version, OS, and minimal reproduction steps
- Search existing issues before creating new ones

## Questions?

Feel free to open an issue for questions or reach out to the maintainers.