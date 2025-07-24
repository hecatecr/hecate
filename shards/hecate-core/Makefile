.PHONY: all test build docs clean format

# Default target
all: test build

# Run tests
test:
	crystal spec

# Build the shard
build:
	crystal build src/hecate-core.cr

# Generate documentation
docs:
	crystal docs

# Clean build artifacts
clean:
	rm -f hecate-core
	rm -rf docs/

# Format code
format:
	crystal tool format

# Check formatting
format-check:
	crystal tool format --check

# Run all checks (useful for CI)
check: format-check test build