require "../src/hecate-lex"

# Token types for a subset of JavaScript
enum MiniJSTokens
  # Keywords
  FUNCTION
  RETURN
  IF
  ELSE
  WHILE
  FOR
  LET
  CONST
  VAR
  TRUE
  FALSE
  NULL
  
  # Identifiers and Literals
  IDENTIFIER
  NUMBER
  STRING
  
  # Operators
  PLUS
  MINUS
  STAR
  SLASH
  PERCENT
  EQUALS
  DOUBLE_EQUALS
  TRIPLE_EQUALS
  NOT_EQUALS
  LESS_THAN
  GREATER_THAN
  LESS_EQUAL
  GREATER_EQUAL
  AND
  OR
  NOT
  
  # Punctuation
  LPAREN
  RPAREN
  LBRACE
  RBRACE
  LBRACKET
  RBRACKET
  SEMICOLON
  COMMA
  DOT
  COLON
  ARROW
  
  # Special
  WHITESPACE
  NEWLINE
  COMMENT
  EOF
end

# Create the Mini JavaScript lexer
def create_mini_js_lexer
  Hecate::Lex.define(MiniJSTokens) do |ctx|
    # Keywords (highest priority to beat identifier matching)
    ctx.token :FUNCTION, /function/, priority: 20
    ctx.token :RETURN, /return/, priority: 20
    ctx.token :IF, /if/, priority: 20
    ctx.token :ELSE, /else/, priority: 20
    ctx.token :WHILE, /while/, priority: 20
    ctx.token :FOR, /for/, priority: 20
    ctx.token :LET, /let/, priority: 20
    ctx.token :CONST, /const/, priority: 20
    ctx.token :VAR, /var/, priority: 20
    ctx.token :TRUE, /true/, priority: 20
    ctx.token :FALSE, /false/, priority: 20
    ctx.token :NULL, /null/, priority: 20
    
    # Identifiers (lower priority than keywords)
    ctx.token :IDENTIFIER, /[a-zA-Z_][a-zA-Z0-9_]*/, priority: 10
    
    # Numbers (integers and floats)
    ctx.token :NUMBER, /\d+(\.\d+)?/, priority: 10
    
    # Strings (single and double quoted)
    ctx.token :STRING, /"([^"\\]|\\.)*"|'([^'\\]|\\.)*'/, priority: 10
    
    # Multi-character operators
    ctx.token :TRIPLE_EQUALS, /===/, priority: 15
    ctx.token :DOUBLE_EQUALS, /==/, priority: 14
    ctx.token :NOT_EQUALS, /!=/, priority: 14
    ctx.token :LESS_EQUAL, /<=/, priority: 14
    ctx.token :GREATER_EQUAL, />=/, priority: 14
    ctx.token :ARROW, /=>/, priority: 14
    ctx.token :AND, /&&/, priority: 14
    ctx.token :OR, /\|\|/, priority: 14
    
    # Single character operators
    ctx.token :PLUS, /\+/, priority: 5
    ctx.token :MINUS, /-/, priority: 5
    ctx.token :STAR, /\*/, priority: 5
    ctx.token :SLASH, /\//, priority: 5
    ctx.token :PERCENT, /%/, priority: 5
    ctx.token :EQUALS, /=/, priority: 5
    ctx.token :LESS_THAN, /</, priority: 5
    ctx.token :GREATER_THAN, />/, priority: 5
    ctx.token :NOT, /!/, priority: 5
    
    # Punctuation
    ctx.token :LPAREN, /\(/
    ctx.token :RPAREN, /\)/
    ctx.token :LBRACE, /\{/
    ctx.token :RBRACE, /\}/
    ctx.token :LBRACKET, /\[/
    ctx.token :RBRACKET, /\]/
    ctx.token :SEMICOLON, /;/
    ctx.token :COMMA, /,/
    ctx.token :DOT, /\./
    ctx.token :COLON, /:/
    
    # Whitespace and comments (skip)
    ctx.token :WHITESPACE, /[ \t]+/, skip: true
    ctx.token :NEWLINE, /\n/, skip: true
    ctx.token :COMMENT, /\/\/[^\n]*|\/\*[\s\S]*?\*\//, skip: true
  end
end

# Main program using ExampleRunner
lexer = create_mini_js_lexer
runner = Hecate::Lex::ExampleRunner.new(lexer, "Mini JavaScript Lexer")

# Configure the runner
runner.configure do |r|
  # Set up token formatting for literals
  r.formatter.add_literal_types(
    MiniJSTokens::IDENTIFIER, 
    MiniJSTokens::NUMBER, 
    MiniJSTokens::STRING
  )
  
  # Custom formatter for comments
  r.formatter.set_custom_handler(MiniJSTokens::COMMENT) do |token, lexeme|
    preview = lexeme.size > 30 ? lexeme[0..27] + "..." : lexeme
    "#{token.kind}(#{preview.inspect})"
  end
  
  # Use detailed output format
  r.output_format = Hecate::Lex::ExampleRunner::OutputFormat::Detailed
  
  # Show statistics
  r.show_statistics = true
end

# Run the example
runner.run!(ARGV)