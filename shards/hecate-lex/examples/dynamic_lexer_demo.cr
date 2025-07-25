require "../src/hecate-lex"

# Example showing the dynamic lexer with minimal boilerplate
# This is useful for quick prototyping or when you don't need
# a predefined enum for your tokens.

# Create a simple expression lexer
lexer = Hecate::Lex.define do |ctx|
  # Keywords
  ctx.token :IF, /if/, priority: 20
  ctx.token :THEN, /then/, priority: 20
  ctx.token :ELSE, /else/, priority: 20

  # Identifiers and literals
  ctx.token :ID, /[a-zA-Z_][a-zA-Z0-9_]*/, priority: 10
  ctx.token :NUM, /\d+(\.\d+)?/, priority: 10
  ctx.token :STR, /"([^"\\]|\\.)*"/, priority: 10

  # Operators
  ctx.token :PLUS, /\+/
  ctx.token :MINUS, /-/
  ctx.token :TIMES, /\*/
  ctx.token :DIV, /\//
  ctx.token :EQ, /=/
  ctx.token :LT, /</
  ctx.token :GT, />/

  # Delimiters
  ctx.token :LPAREN, /\(/
  ctx.token :RPAREN, /\)/

  # Whitespace
  ctx.token :WS, /\s+/, skip: true
end

# Parse arguments
result, source_map, source_file = Hecate::Lex::CLI.setup(ARGV, "Dynamic Lexer Demo")

# Lex the source
tokens, diagnostics = lexer.scan(source_file)

# Print diagnostics if any
if diagnostics.any?
  Hecate::Lex::CLI.print_header("Diagnostics")
  printer = Hecate::Lex::DiagnosticPrinter.new(source_file)
  printer.print_simple(diagnostics)
  puts
end

# Print tokens
Hecate::Lex::CLI.print_header("Tokens")
tokens.each do |token|
  next if token.kind_name == "EOF"

  pos = source_file.byte_to_position(token.span.start_byte)
  lexeme = token.lexeme(source_file)

  # Format based on token type
  case token.kind_name
  when "ID", "NUM", "STR"
    puts "  #{token.kind_name.ljust(8)} #{lexeme.inspect}"
  else
    puts "  #{token.kind_name.ljust(8)} '#{lexeme}'"
  end
end

# Print summary
puts
Hecate::Lex::CLI.print_summary({
  "Total Tokens" => tokens.size - 1, # Exclude EOF
  "Diagnostics"  => diagnostics.size,
})
