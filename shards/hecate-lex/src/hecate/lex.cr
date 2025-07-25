require "hecate-core"
require "./lex/token"
require "./lex/rule"
require "./lex/scanner"
require "./lex/lexer"
require "./lex/token_stream"
require "./lex/dsl"
require "./lex/error_handlers"

# Utilities for examples and tools
require "./lex/token_formatter"
require "./lex/nesting_tracker"
require "./lex/cli"
require "./lex/diagnostic_printer"
require "./lex/token_stream_printer"
require "./lex/example_runner"

# Main module for Hecate lexer functionality
module Hecate::Lex
  VERSION = "0.1.0"
end
