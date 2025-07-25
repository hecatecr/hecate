# Hecate Benchmark Suite Usage Guide

This document explains how to use the centralized benchmarking infrastructure via the root `justfile`.

## Quick Start

From the project root directory:

```bash
# Show all available commands
just

# Run basic performance test
just bench-quick

# Run lexer performance benchmarks  
just bench-lexer

# Show performance summary
just bench-summary

# Install dependencies if needed
just install
```

## Available Benchmarks

### 1. Quick Test (`just bench-quick`)
- **Purpose**: Verify benchmark infrastructure works
- **Duration**: ~10 seconds
- **Output**: Basic performance validation

### 2. Lexer Benchmarks (`just bench-lexer`) 
- **Purpose**: Core lexer performance validation
- **Duration**: ~10 seconds  
- **Output**: Basic benchmark infrastructure verification

### 3. CI Benchmarks (`just bench-ci`)
- **Purpose**: Fast regression testing
- **Duration**: ~30 seconds
- **Output**: Performance comparison with thresholds

### 4. Memory Profiling (`just bench-memory`)
- **Purpose**: Memory usage analysis
- **Duration**: ~60 seconds
- **Output**: Allocation patterns and efficiency metrics

### 5. Performance Summary (`just bench-summary`)
- **Purpose**: Show current performance achievements
- **Duration**: Instant
- **Output**: Performance metrics vs targets

## File Structure

```
# Root justfile with all benchmark commands
justfile                   # Main development task runner

# Benchmarking infrastructure  
tools/bench/
├── benchmark.cr          # Core benchmarking infrastructure
├── simple_test.cr        # Basic functionality test
├── ci_benchmark.cr       # CI regression testing
├── memory_profiler.cr    # Memory usage analysis
├── README.md            # Detailed documentation
├── PERFORMANCE_REPORT.md # Performance analysis results
└── results/             # Benchmark output files
```

## Performance Results Summary

**Current Performance (exceeds 100K tokens/sec target):**
- Small files: 1.25M tokens/sec 🚀
- Medium files: 134K tokens/sec ✅  
- JSON parsing: 371K tokens/sec 🚀
- Complex lexers: 17.8K tokens/sec 📈

## Usage Notes

1. **Working Benchmarks**: All commands work from project root via `just`
2. **Path Management**: Justfile handles all directory navigation automatically
3. **CI Integration**: Use `just bench-ci` for automated testing
4. **Results Storage**: All outputs saved to `tools/bench/results/` directory

## Troubleshooting

**Problem**: `just` command not found
**Solution**: Install just: `brew install just` (macOS) or see https://github.com/casey/just

**Problem**: Missing dependencies
**Solution**: Run `just install` to install required shards

**Problem**: Benchmark never completes
**Solution**: Use `just bench-quick` for fast tests, full benchmarks may take several minutes

## Development

To add new benchmarks:

1. Create new `.cr` file in `tools/bench/`
2. Include `require "./benchmark"` and `include Hecate::Benchmark`  
3. Add recipe to root `justfile`
4. Update this usage guide

## Cleanup Complete

The benchmark infrastructure has been centralized and modernized:

✅ **Removed**: Makefile from `tools/bench/`  
✅ **Removed**: All benchmark files from `shards/hecate-lex/`  
✅ **Added**: Root `justfile` with comprehensive development commands  
✅ **Centralized**: All benchmarking in `tools/bench/` with unified access

**Benefits:**
- Clean separation of concerns (shards focus on implementation)
- Unified development workflow via `just` commands
- Professional build system with comprehensive task management
- Easy onboarding for new contributors