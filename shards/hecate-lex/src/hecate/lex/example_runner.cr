module Hecate::Lex
  # Complete example runner that handles all boilerplate for lexer examples
  #
  # Combines CLI parsing, source reading, lexing, diagnostic printing,
  # and token stream output into a simple, customizable runner.
  #
  # Example:
  # ```
  # # Define your token types
  # enum MyTokens
  #   NUMBER
  #   STRING
  #   IDENTIFIER
  #   # ... etc
  #   EOF
  # end
  #
  # # Create your lexer
  # lexer = Hecate::Lex.define(MyTokens) do |ctx|
  #   ctx.token :NUMBER, /\d+/
  #   ctx.token :STRING, /"[^"]*"/
  #   # ... etc
  # end
  #
  # # Run the example
  # runner = ExampleRunner.new(lexer, "My Language Lexer")
  # runner.configure do |r|
  #   r.formatter.add_literal_types(MyTokens::NUMBER, MyTokens::STRING)
  #   r.show_statistics = true
  # end
  # runner.run(ARGV)
  # ```
  class ExampleRunner(T)
    # The lexer to use
    getter lexer : Lexer(T)

    # Name of the example/language
    getter name : String

    # Token formatter
    property formatter : TokenFormatter(T)

    # Token stream printer
    property token_printer : TokenStreamPrinter(T)

    # Diagnostic printer (created per run)
    getter diagnostic_printer : DiagnosticPrinter?

    # Optional nesting tracker
    property nesting_tracker : NestingTracker(T)?

    # Configuration options
    property show_banner : Bool = true
    property show_statistics : Bool = false
    property show_summary : Bool = true
    property show_structure_validation : Bool = false
    property output_format : OutputFormat = OutputFormat::Detailed

    # Output format options
    enum OutputFormat
      Simple     # Just token names
      Detailed   # With positions and indices
      Structured # With nesting indentation
      Compact    # All on one line
    end

    def initialize(@lexer : Lexer(T), @name : String)
      @formatter = TokenFormatter(T).new
      @token_printer = TokenStreamPrinter(T).new(@formatter)
    end

    # Configure the runner with a block
    def configure(&block : self ->)
      yield self

      # Update token printer with formatter
      @token_printer.formatter = @formatter

      # Set nesting tracker if configured
      @token_printer.nesting_tracker = @nesting_tracker
    end

    # Run the example with given arguments
    def run(args : Array(String), io : IO = STDOUT, error_io : IO = STDERR)
      # Parse arguments and setup
      result, source_map, source_file = CLI.setup(args, @name)

      # Print banner
      if @show_banner
        print_banner(result.input_path, source_file, io)
      end

      # Lex the source
      tokens, diagnostics = @lexer.scan(source_file)

      # Print diagnostics if any
      if diagnostics.any?
        CLI.print_header("Diagnostics", io)
        printer = DiagnosticPrinter.new(source_file, show_context: true)
        printer.print(diagnostics, error_io)
        io.puts
      end

      # Print token stream
      print_tokens(tokens, source_file, source_map, io)

      # Print statistics if requested
      if @show_statistics
        io.puts
        CLI.print_header("Token Statistics", io)
        @token_printer.print_statistics(tokens, io)
      end

      # Print summary if requested
      if @show_summary
        io.puts
        print_summary(tokens, diagnostics, source_file, io)
      end

      # Structure validation if configured
      if @show_structure_validation && @nesting_tracker
        io.puts
        print_structure_validation(io)
      end

      # Return success/failure based on diagnostics
      diagnostics.empty? ? 0 : 1
    end

    # Run and exit with status code
    def run!(args : Array(String))
      status = run(args)
      exit status
    end

    private def print_banner(path : String, source_file : Hecate::Core::SourceFile, io : IO)
      display_path = path == "-" ? "stdin" : path
      io.puts "=== #{@name} - Lexing #{display_path} ==="
      io.puts "File size: #{CLI.format_file_size(source_file.contents.bytesize)}"
      io.puts
    end

    private def print_tokens(tokens : Array(Token(T)),
                             source_file : Hecate::Core::SourceFile,
                             source_map : Hecate::Core::SourceMap,
                             io : IO)
      CLI.print_header("Token Stream", io)

      case @output_format
      when .simple?
        @token_printer.print_simple(tokens, source_map, io)
      when .detailed?
        @token_printer.print(tokens, source_file, source_map, io)
      when .structured?
        @token_printer.print_structured(tokens, source_file, source_map, io)
      when .compact?
        @token_printer.print_compact(tokens, source_map, io)
      end
    end

    private def print_summary(tokens : Array(Token(T)),
                              diagnostics : Array(Hecate::Core::Diagnostic),
                              source_file : Hecate::Core::SourceFile,
                              io : IO)
      # Count non-EOF tokens
      token_count = tokens.count { |t| !is_eof?(t) }

      stats = {
        total_tokens: token_count,
        diagnostics:  diagnostics.size,
        lines:        source_file.line_offsets.size,
        bytes:        source_file.contents.bytesize,
      }

      # Add error count if any
      error_count = diagnostics.count(&.severity.error?)
      if error_count > 0
        stats = stats.merge({errors: error_count})
      end

      CLI.print_summary(stats, io)
    end

    private def print_structure_validation(io : IO)
      tracker = @nesting_tracker
      return unless tracker

      if tracker.balanced?
        io.puts "Structure: ✓ All brackets balanced"
      else
        io.puts "Structure: ✗ #{tracker.validation_error}"
      end
    end

    private def is_eof?(token : Token(T)) : Bool
      token.kind.to_s.upcase == "EOF"
    end
  end

  # Convenience method to create and run an example
  def self.run_example(lexer : Lexer(T), name : String, args : Array(String)) forall T
    runner = ExampleRunner.new(lexer, name)
    runner.run!(args)
  end
end
