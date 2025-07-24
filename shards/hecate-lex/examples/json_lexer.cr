require "../src/hecate-lex"

# Token types for JSON
enum JSONTokens
  # Literals
  STRING
  NUMBER
  TRUE
  FALSE
  NULL

  # Structural
  LBRACE   # {
  RBRACE   # }
  LBRACKET # [
  RBRACKET # ]
  COMMA    # ,
  COLON    # :

  # Special
  WHITESPACE
  EOF
end

# Create the JSON lexer
def create_json_lexer
  Hecate::Lex.define(JSONTokens) do |ctx|
    # Keywords (must be higher priority than string to match correctly)
    ctx.token :TRUE, /true/, priority: 20
    ctx.token :FALSE, /false/, priority: 20
    ctx.token :NULL, /null/, priority: 20

    # String - handles escaped characters (simplified)
    ctx.token :STRING, /"([^"\\]|\\.)*"/, priority: 10

    # Number - handles integers, decimals, and scientific notation
    ctx.token :NUMBER, /-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?/, priority: 10

    # Structural characters
    ctx.token :LBRACE, /\{/
    ctx.token :RBRACE, /\}/
    ctx.token :LBRACKET, /\[/
    ctx.token :RBRACKET, /\]/
    ctx.token :COMMA, /,/
    ctx.token :COLON, /:/

    # Whitespace (skip)
    ctx.token :WHITESPACE, /[ \t\n\r]+/, skip: true
  end
end

# Main program using ExampleRunner
lexer = create_json_lexer
runner = Hecate::Lex::ExampleRunner.new(lexer, "JSON Lexer")

# Configure the runner
runner.configure do |r|
  # Set up token formatting
  r.formatter.add_literal_types(JSONTokens::STRING, JSONTokens::NUMBER)
  
  # Use structured output for JSON
  r.output_format = Hecate::Lex::ExampleRunner::OutputFormat::Structured
  
  # Set up nesting tracker for proper indentation
  r.nesting_tracker = Hecate::Lex::NestingTracker.new(
    open_tokens: [JSONTokens::LBRACE, JSONTokens::LBRACKET],
    close_tokens: [JSONTokens::RBRACE, JSONTokens::RBRACKET],
    pairs: {
      JSONTokens::RBRACE => JSONTokens::LBRACE,
      JSONTokens::RBRACKET => JSONTokens::LBRACKET
    }
  )
  
  # Enable structure validation
  r.show_structure_validation = true
  r.show_statistics = true
end

# Run the example
runner.run!(ARGV)