# hecate-lex

A powerful lexical analysis library for Crystal that provides a macro-based DSL for defining lexers with comprehensive error handling and diagnostic support.

## Features

- 🎯 **Declarative DSL** - Define tokens using readable macro syntax
- 🏆 **Longest-Match-Wins** - Automatic conflict resolution using token priorities
- 🔍 **Rich Diagnostics** - Integration with `hecate-core` for detailed error reporting
- 🔄 **Error Recovery** - Continue lexing after encountering invalid input
- 🚀 **High Performance** - Optimized for 100k+ tokens/second throughput
- 🌍 **Unicode Support** - Full Unicode support with proper multi-byte handling
- 🎨 **Dynamic Lexers** - Create lexers at runtime without predefined enums
- 🔗 **Nesting Tracking** - Built-in support for tracking paired tokens

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  hecate-lex:
    github: hecatecr/hecate-lex
    version: ~> 0.1.0
```

Run `shards install` to install dependencies.

## Quick Start

### Basic Usage

```crystal
require "hecate-lex"

# Define a simple calculator lexer
calculator_lexer = Hecate::Lex.define do
  # Skip whitespace
  token :WS, /\s+/, skip: true
  
  # Numbers
  token :INTEGER, /\d+/
  token :FLOAT, /\d+\.\d+/
  
  # Operators
  token :PLUS, /\+/
  token :MINUS, /-/
  token :MULTIPLY, /\*/
  token :DIVIDE, /\//
  
  # Parentheses
  token :LPAREN, /\(/
  token :RPAREN, /\)/
  
  # Identifiers
  token :IDENTIFIER, /[a-zA-Z_]\w*/
end

# Create a source map and add input
source_map = Hecate::Core::SourceMap.new
source_id = source_map.add_file("input.calc", "3.14 + x * (2 + 1)")

# Scan the input
tokens, diagnostics = calculator_lexer.scan(source_map.get(source_id).not_nil!)

# Process tokens
tokens.each do |token|
  puts "#{token.kind}: '#{token.lexeme(source_map)}'"
end
```

### Type-Safe Lexers

For better type safety, define lexers with an enum:

```crystal
enum CalcToken
  # Skip tokens
  WS
  
  # Literals
  INTEGER
  FLOAT
  IDENTIFIER
  
  # Operators
  PLUS
  MINUS
  MULTIPLY
  DIVIDE
  
  # Delimiters
  LPAREN
  RPAREN
end

# Define lexer with enum
lexer = Hecate::Lex.define(CalcToken) do |ctx|
  ctx.token CalcToken::WS, /\s+/, skip: true
  ctx.token CalcToken::FLOAT, /\d+\.\d+/
  ctx.token CalcToken::INTEGER, /\d+/
  # ... rest of tokens
end
```

## API Reference

### DSL Methods

Create lexers using the declarative DSL:

```crystal
# Dynamic lexer (runtime token types)
lexer = Hecate::Lex.define do
  token :KIND, /pattern/           # Basic token
  token :WS, /\s+/, skip: true     # Skip token
  token :ID, /\w+/, priority: 10   # With priority
  
  # Error handlers
  error :handler_name do |input, pos|
    # Return a diagnostic
  end
end

# Type-safe lexer with enum
lexer = Hecate::Lex.define(TokenEnum) do |ctx|
  ctx.token TokenEnum::KIND, /pattern/
end
```

### Token Priorities

The lexer uses a longest-match-wins strategy with priority resolution:

```crystal
lexer = Hecate::Lex.define do
  # Higher priority wins for same-length matches
  token :ELSE_IF, /else\s+if/, priority: 20
  token :ELSE, /else/, priority: 10
  token :IF, /if/, priority: 10
  token :IDENTIFIER, /[a-zA-Z_]\w*/, priority: 1
end
```

Default priorities:
- Keywords: 10
- Operators: 5-8
- Identifiers: 1
- Others: 5

### Error Handling

Built-in error handlers for common cases:

```crystal
lexer = Hecate::Lex.define do
  # Use built-in handlers
  token :STRING, /"([^"\\]|\\.)*"/, 
    error: Hecate::Lex::CommonErrors::UNTERMINATED_STRING
  
  token :COMMENT, /\/\*.*?\*\//, 
    error: Hecate::Lex::CommonErrors::UNTERMINATED_COMMENT
    
  # Custom error handler
  error :invalid_escape do |input, pos|
    Hecate.error("invalid escape sequence")
      .primary(span, "unknown escape character")
      .help("valid escapes are: \\n, \\t, \\r, \\\\, \\\"")
  end
end
```

Available built-in handlers:
- `UNTERMINATED_STRING`
- `UNTERMINATED_COMMENT`
- `INVALID_ESCAPE`
- `INVALID_NUMBER`
- `INVALID_CHARACTER`

### Nesting Tracker

Track paired tokens for proper nesting validation:

```crystal
# Use built-in bracket tracker
tracker = Hecate::Lex.bracket_tracker

# Or create custom tracker
tracker = Hecate::Lex::NestingTracker.new do |t|
  t.pair :LPAREN, :RPAREN
  t.pair :LBRACE, :RBRACE
  t.pair :BEGIN, :END
end

# Process tokens
tokens.each do |token|
  indent_level = tracker.process(token)
  puts "#{"  " * indent_level}#{token.kind}: #{token.lexeme(source_map)}"
end

# Validate nesting
unless tracker.balanced?
  unclosed = tracker.unclosed_tokens
  error_msg = tracker.validation_error
  # Handle unmatched tokens
end
```

### Scanner API

Direct access to the scanner for advanced use cases:

```crystal
# Create scanner
scanner = Hecate::Lex::Scanner.new(
  rule_set, 
  source_id, 
  source_map
)

# Scan all tokens
tokens, diagnostics = scanner.scan_all

# Scanner automatically:
# - Implements longest-match-wins
# - Resolves conflicts by priority
# - Recovers from errors
# - Tracks source positions
```

### Token API

Work with token objects:

```crystal
# Token structure
token.kind        # Token type (Symbol or Enum value)
token.span        # Source location (Hecate::Core::Span)
token.value       # Optional semantic value

# Get token text
lexeme = token.lexeme(source_map)

# Compare tokens
token1 == token2  # Structural equality
```

### Dynamic Lexers

Create lexers at runtime without predefined types:

```crystal
# Dynamic lexer returns DynamicToken objects
lexer = Hecate::Lex.define do
  token :NUMBER, /\d+/
  token :WORD, /\w+/
end

tokens, _ = lexer.scan(source)
tokens.each do |token|
  puts token.kind_name  # "NUMBER", "WORD", etc.
end
```

## Testing

### Test Utilities

Use built-in test helpers:

```crystal
require "hecate-core/test_utils"

# Golden file testing for lexer output
GoldenFile.test("lexer/json/simple", token_output)

# Snapshot testing
Snapshot.match("lexer_output", formatted_tokens)

# Custom matchers
tokens.should contain_token(:IDENTIFIER, "foo")
diagnostics.should have_error("invalid character")
```

### Example Test

```crystal
describe "JSON Lexer" do
  it "tokenizes objects" do
    source = create_test_source('{"key": "value"}')
    tokens, diagnostics = json_lexer.scan(source)
    
    token_kinds = tokens.map(&.kind)
    token_kinds.should eq([
      :LBRACE, :STRING, :COLON, :STRING, :RBRACE
    ])
    
    diagnostics.should be_empty
  end
end
```

## Examples

The `examples/` directory contains complete working examples:

### JSON Lexer (`json_lexer.cr`)
```crystal
json_lexer = Hecate::Lex.define do
  token :WS, /\s+/, skip: true
  token :LBRACE, /\{/
  token :RBRACE, /\}/
  token :STRING, /"([^"\\]|\\.)*"/
  # ... more tokens
end
```

### Mini JavaScript Lexer (`mini_js_lexer.cr`)
```crystal
js_lexer = Hecate::Lex.define do
  # Keywords (high priority)
  token :FUNCTION, /function/, priority: 10
  token :RETURN, /return/, priority: 10
  
  # Identifiers (low priority)  
  token :IDENTIFIER, /[a-zA-Z_]\w*/, priority: 1
  # ... more tokens
end
```

### Dynamic Lexer Demo (`dynamic_lexer_demo.cr`)
Shows runtime lexer creation and usage.

## Performance

Optimizations for high-throughput lexing:

- **Pre-sorted rules** by priority and pattern length
- **Direct regex matching** without anchored regex creation
- **Pre-allocated token arrays** based on input size estimate
- **Early exit conditions** in scanning loop
- **Minimal allocations** in hot paths

Benchmarks show 100k+ tokens/second on typical source code.

## Contributing

1. Fork it (https://github.com/hecatecr/hecate-lex/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Add comprehensive tests for new functionality
4. Ensure all tests pass (`crystal spec`)
5. Follow Crystal coding conventions
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a new Pull Request

## License

This library is released under the MIT License. See [LICENSE](LICENSE) for details.

## Contributors

- [Chris Watson](https://github.com/watzon) - creator and maintainer