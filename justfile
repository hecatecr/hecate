# Hecate Development Tasks
#
# This justfile provides common development tasks for the Hecate monorepo.
# Install just: https://github.com/casey/just

# Set environment variables for all recipes
export SHARDS_OVERRIDE := "shard.dev.yml"

# Default recipe - show available commands
default:
    @just --list

# Development Tasks
# =================

# Install dependencies (run from root using development shards)
install:
    @echo "📦 Installing dependencies for development environment..."
    @shards install
    @echo "✅ Dependencies installed using development configuration"

# Run tests for all shards (from root directory)
test:
    @echo "🧪 Running tests for all shards..."
    @echo "📦 Ensuring dependencies are installed..."
    @shards install
    @crystal spec shards/hecate-core/spec --error-on-warnings
    @crystal spec shards/hecate-lex/spec --error-on-warnings
    @crystal spec shards/hecate-ast/spec --error-on-warnings
    @echo "✅ All tests passed"

# Run tests for a specific shard (from root directory)
test-shard shard:
    @echo "🧪 Running tests for {{shard}}..."
    @echo "📦 Ensuring dependencies are installed..."
    @shards install
    @crystal spec shards/hecate-{{shard}}/spec --error-on-warnings

# Check compilation of all shards (from root directory)
check:
    @echo "🔍 Checking compilation of all shards..."
    @crystal build --no-codegen shards/hecate-core/src/**/*.cr
    @crystal build --no-codegen shards/hecate-lex/src/**/*.cr
    @crystal build --no-codegen shards/hecate-ast/src/**/*.cr
    @echo "✅ All shards compile successfully"

# Performance Benchmarking
# ========================

# Run quick benchmark test
bench-quick:
    @echo "⚡ Running quick benchmark..."
    @mkdir -p tools/bench/results
    @crystal run --release tools/bench/simple_test.cr

# Run comprehensive lexer performance benchmarks
bench-lexer:
    @echo "🔤 Running comprehensive lexer benchmarks..."
    @mkdir -p tools/bench/results
    @crystal run --release tools/bench/comprehensive_lexer_bench.cr

# Run full lexer benchmarks (alternative comprehensive suite)
bench-lexer-full:
    @echo "🔤 Running full lexer benchmark suite..."
    @mkdir -p tools/bench/results
    @crystal run --release tools/bench/lexer_benchmarks.cr

# Run CI benchmark suite (for regression testing)
bench-ci:
    @echo "🔄 Running CI benchmark suite..."
    @mkdir -p tools/bench/results
    @crystal run --release tools/bench/ci_benchmark.cr

# Run memory profiling analysis
bench-memory:
    @echo "🧠 Running memory profiling..."
    @mkdir -p tools/bench/results
    @crystal run --release tools/bench/memory_profiler.cr

# Clean benchmark results
bench-clean:
    @echo "🧹 Cleaning benchmark results..."
    @rm -rf tools/bench/results
    @echo "✅ Results cleaned"

# Examples and Documentation
# ==========================

# Run JSON lexer example
example-json:
    @echo "📄 Running JSON lexer example..."
    @crystal run shards/hecate-lex/examples/json_lexer.cr -- shards/hecate-lex/examples/sample.json

# Run JavaScript lexer example
example-js:
    @echo "📄 Running JavaScript lexer example..."
    @crystal run shards/hecate-lex/examples/mini_js_lexer.cr -- shards/hecate-lex/examples/sample.js

# Run dynamic lexer demo
example-dynamic:
    @echo "📄 Running dynamic lexer demo..."
    @crystal run shards/hecate-lex/examples/dynamic_lexer_demo.cr

# Generate Crystal documentation
docs:
    @echo "📚 Generating Crystal documentation..."
    @crystal docs shards/hecate-core/src/hecate-core.cr --project-name="Hecate Core" --project-version="0.1.0" --output=docs/hecate-core
    @crystal docs shards/hecate-lex/src/hecate-lex.cr --project-name="Hecate Lex" --project-version="0.1.0" --output=docs/hecate-lex
    @echo "✅ Documentation generated in docs/ directory"

# Release Management
# ==================

# Build all shards in release mode
build:
    @echo "🔨 Building all shards in release mode..."
    @crystal build --release shards/hecate-core/src/hecate-core.cr -o bin/hecate-core
    @crystal build --release shards/hecate-lex/src/hecate-lex.cr -o bin/hecate-lex
    @echo "✅ All shards built successfully in bin/ directory"

# Run full validation (tests + benchmarks + examples)
validate:
    @echo "🔬 Running full project validation..."
    @just install
    @just test
    @just check
    @just bench-quick
    @just example-json
    @echo "✅ Full validation completed successfully"

# Git Subtree Management
# ======================

# List all configured shard remotes
list-remotes:
    @echo "📡 Configured shard remotes:"
    @git remote -v | grep -E "(core|lex|parse|ast|sem|ir|codegen|cli)-remote"

# Add all shard remotes (run after cloning monorepo)
add-remotes:
    @echo "➕ Adding shard remotes..."
    @git remote add core-remote git@github.com:hecatecr/hecate-core.git || true
    @git remote add lex-remote git@github.com:hecatecr/hecate-lex.git || true
    @git remote add ast-remote git@github.com:hecatecr/hecate-ast.git || true
    @echo "✅ Remotes added"

# Push a specific shard to its repository
push-shard shard branch="main":
    @echo "🚀 Pushing {{shard}} to {{branch}}..."
    @git subtree push --prefix=shards/hecate-{{shard}} {{shard}}-remote {{branch}}
    @echo "✅ Successfully pushed hecate-{{shard}}"

# Push all shards to their repositories
push-all branch="main":
    @echo "🚀 Pushing all shards to {{branch}}..."
    @just push-shard core {{branch}}
    @just push-shard lex {{branch}}
    @just push-shard ast {{branch}}
    @echo "✅ All shards pushed successfully"

# Push all changes (monorepo + shards)
push-everything:
    @echo "📤 Pushing monorepo changes..."
    @git push origin main
    @echo "🚀 Pushing all shards..."
    @just push-all
    @echo "✅ Everything pushed successfully!"

# Force push a shard (use with caution!)
force-push-shard shard branch="main":
    @echo "⚠️  Force pushing {{shard}} to {{branch}}..."
    @git push {{shard}}-remote `git subtree split --prefix=shards/hecate-{{shard}} HEAD`:{{branch}} --force
    @echo "✅ Force pushed hecate-{{shard}}"

# Create a subtree split for a shard (useful for debugging)
split-shard shard:
    @echo "✂️  Creating subtree split for {{shard}}..."
    @git subtree split --prefix=shards/hecate-{{shard}} HEAD
    @echo "✅ Split created"

# Push a specific tag to all shard repositories
push-tag tag:
    @echo "🏷️  Pushing tag {{tag}} to all shards..."
    @git subtree push --prefix=shards/hecate-core core-remote refs/tags/{{tag}}
    @git subtree push --prefix=shards/hecate-lex lex-remote refs/tags/{{tag}}
    @git subtree push --prefix=shards/hecate-ast ast-remote refs/tags/{{tag}}
    @echo "✅ Tag {{tag}} pushed to all shards"

# Create and push a release
release version:
    @echo "📦 Creating release {{version}}..."
    @# Ensure we're on main and up to date
    @git checkout main
    @git pull origin main
    @# Run validation
    @just validate
    @# Create and push tag
    @git tag -a v{{version}} -m "Release v{{version}}"
    @git push origin v{{version}}
    @# Push to shard repos
    @just push-all main
    @just push-tag v{{version}}
    @echo "✅ Release v{{version}} complete!"

# Dry run - show what would be pushed without actually pushing
dry-run-push shard:
    @echo "🔍 Dry run for {{shard}}..."
    @echo "Would push the following commits:"
    @git log --oneline $(git subtree split --prefix=shards/hecate-{{shard}} HEAD)..HEAD -- shards/hecate-{{shard}}

# Check status of all shards (what would be pushed)
status:
    @echo "📊 Subtree push status:"
    @echo ""
    @echo "hecate-core:"
    @git log --oneline -5 -- shards/hecate-core | head -5 || echo "  No recent changes"
    @echo ""
    @echo "hecate-lex:"
    @git log --oneline -5 -- shards/hecate-lex | head -5 || echo "  No recent changes"

# Check full status including monorepo
status-all:
    @echo "📊 Full repository status:"
    @echo ""
    @echo "🏠 Monorepo (unpushed commits):"
    @git log --oneline -5 --branches --not --remotes || echo "  All changes pushed"
    @echo ""
    @just status

# Show help for subtree workflow
subtree-help:
    @echo "🌳 Git Subtree Workflow for Hecate"
    @echo ""
    @echo "Initial setup (after GitHub repos are created):"
    @echo "  just add-remotes        # Add remotes for all shards"
    @echo ""
    @echo "First push to populate repos:"
    @echo "  just push-all           # Push all shards to main branch"
    @echo ""
    @echo "Regular workflow:"
    @echo "  just status             # Check what would be pushed"
    @echo "  just push-shard core    # Push specific shard"
    @echo "  just push-all           # Push all shards"
    @echo ""
    @echo "Creating a release:"
    @echo "  just release 0.1.0      # Create and push release v0.1.0"
    @echo ""
    @echo "Troubleshooting:"
    @echo "  just dry-run-push core  # See what would be pushed"
    @echo "  just split-shard core   # Create subtree split manually"
    @echo "  just force-push-shard core  # Force push if needed"

# Development Utilities
# =====================

# Format all Crystal code
format:
    @echo "💎 Formatting Crystal code..."
    @crystal tool format .
    @echo "✅ Code formatted"
