# Hecate Lexer Examples

This directory contains real-world examples demonstrating the Hecate lexer toolkit.

## Examples

### 1. Mini JavaScript Lexer (`mini_js_lexer.cr`)

A lexer for a subset of JavaScript that demonstrates:
- Keyword recognition with priority handling
- Identifier and literal tokenization  
- Multi-character operators (===, &&, =>, etc.)
- String literals with escape sequences
- Single and multi-line comments
- Whitespace handling

**Run the example:**
```bash
# Lex the sample JavaScript file
crystal run mini_js_lexer.cr -- sample.js

# Or pipe input from stdin
echo 'const x = 42;' | crystal run mini_js_lexer.cr -- -
```

**Supported tokens:**
- Keywords: function, return, if, else, while, for, let, const, var, true, false, null
- Operators: +, -, *, /, %, =, ==, ===, !=, <, >, <=, >=, &&, ||, !, =>
- Literals: numbers (integers and floats), strings (single and double quoted)
- Punctuation: (), {}, [], ;, ,, .

### 2. JSON Lexer (`json_lexer.cr`)

A complete JSON lexer that demonstrates:
- String tokenization with escape sequence support
- Number parsing (integers, decimals, scientific notation)
- Structural token handling
- Whitespace skipping
- Structure validation (balanced braces/brackets)

**Run the example:**
```bash
# Lex the sample JSON file
crystal run json_lexer.cr -- clean_sample.json

# Or pipe input from stdin
echo '{"key": "value"}' | crystal run json_lexer.cr -- -
```

**Supported tokens:**
- Literals: strings (with escape sequences), numbers, true, false, null
- Structural: {, }, [, ], :, ,
- Whitespace is automatically skipped

## Output Format

Both lexers output:
1. **Diagnostics** - Any lexical errors found
2. **Token Stream** - All tokens with line:column positions
3. **Summary** - Total token count and diagnostic count

Example output:
```
=== Token Stream ===
  0: [1:1 ] LBRACE
  1: [1:2 ] STRING("key")
  2: [1:7 ] COLON
  3: [1:9 ] STRING("value")
  4: [1:16] RBRACE
  5: [1:17] EOF
```

## Creating Your Own Lexer

Use these examples as templates for your own lexers:

1. Define your token enum
2. Create rules with appropriate patterns and priorities
3. Handle whitespace and comments with skip flags
4. Use the token stream for parsing or analysis

```crystal
enum MyTokens
  KEYWORD
  IDENTIFIER
  NUMBER
  EOF
end

lexer = Hecate::Lex.define(MyTokens) do |ctx|
  ctx.token :KEYWORD, /if|then|else/, priority: 20
  ctx.token :IDENTIFIER, /[a-zA-Z]+/, priority: 10
  ctx.token :NUMBER, /\d+/, priority: 10
end
```