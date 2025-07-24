module Hecate::Lex
  # Utility for printing token streams in various formats
  #
  # Supports:
  # - Simple list format
  # - Detailed format with positions
  # - Structured format with nesting
  # - Custom formatting
  #
  # Example:
  # ```
  # printer = TokenStreamPrinter.new(formatter)
  # printer.print(tokens, source_file)
  # ```
  class TokenStreamPrinter(T)
    # Token formatter to use
    property formatter : TokenFormatter(T)
    
    # Whether to show token indices
    getter show_indices : Bool
    
    # Whether to show position information
    getter show_positions : Bool
    
    # Whether to skip EOF token
    getter skip_eof : Bool
    
    # Optional nesting tracker for structured output
    property nesting_tracker : NestingTracker(T)?
    
    def initialize(@formatter : TokenFormatter(T)? = nil,
                   @show_indices = true,
                   @show_positions = true, 
                   @skip_eof = true)
      @formatter ||= TokenFormatter(T).new
    end
    
    # Print tokens in default format
    def print(tokens : Array(Token(T)), source_file : Hecate::Core::SourceFile, source_map : Hecate::Core::SourceMap, io : IO = STDOUT)
      tokens.each_with_index do |token, index|
        next if @skip_eof && is_eof?(token)
        
        print_token(token, index, source_file, source_map, io)
      end
    end
    
    # Print tokens in a simple format (no positions or indices)
    def print_simple(tokens : Array(Token(T)), source_map : Hecate::Core::SourceMap, io : IO = STDOUT)
      tokens.each do |token|
        next if @skip_eof && is_eof?(token)
        
        io.puts @formatter.format(token, source_map)
      end
    end
    
    # Print tokens with structure-aware formatting
    def print_structured(tokens : Array(Token(T)), source_file : Hecate::Core::SourceFile, source_map : Hecate::Core::SourceMap, io : IO = STDOUT)
      tracker = @nesting_tracker
      return print(tokens, source_file, source_map, io) unless tracker
      
      tokens.each_with_index do |token, index|
        next if @skip_eof && is_eof?(token)
        
        # Get nesting level before processing
        level = tracker.process(token.kind)
        
        # Print with indentation
        print_token_with_indent(token, index, level, source_file, source_map, io)
      end
      
      # Print validation status
      unless tracker.balanced?
        io.puts
        io.puts "Structure validation: #{tracker.validation_error}"
      end
    end
    
    # Print tokens in a compact format suitable for debugging
    def print_compact(tokens : Array(Token(T)), source_map : Hecate::Core::SourceMap, io : IO = STDOUT)
      tokens.each_with_index do |token, index|
        next if @skip_eof && is_eof?(token)
        
        io.print @formatter.format(token, source_map)
        io.print " " unless index == tokens.size - 1
      end
      io.puts
    end
    
    # Print token statistics
    def print_statistics(tokens : Array(Token(T)), io : IO = STDOUT)
      # Count tokens by type
      counts = Hash(T, Int32).new(0)
      tokens.each do |token|
        counts[token.kind] += 1
      end
      
      # Sort by count (descending) then by name
      sorted = counts.to_a.sort do |a, b|
        cmp = b[1] <=> a[1]
        cmp == 0 ? a[0].to_s <=> b[0].to_s : cmp
      end
      
      # Find longest token name for formatting
      max_width = sorted.map { |kind, _| kind.to_s.size }.max? || 10
      
      io.puts "Token Statistics:"
      io.puts "-" * (max_width + 10)
      
      sorted.each do |kind, count|
        io.puts "#{kind.to_s.ljust(max_width)} : #{count}"
      end
      
      io.puts "-" * (max_width + 10)
      io.puts "Total: #{tokens.size} tokens"
    end
    
    private def print_token(token : Token(T), index : Int32, source_file : Hecate::Core::SourceFile, source_map : Hecate::Core::SourceMap, io : IO)
      parts = [] of String
      
      # Add index
      if @show_indices
        parts << "#{index.to_s.rjust(3)}:"
      end
      
      # Add position
      if @show_positions
        pos = source_file.byte_to_position(token.span.start_byte)
        parts << "[#{pos.display_line}:#{pos.display_column.to_s.ljust(2)}]"
      end
      
      # Add formatted token
      parts << @formatter.format(token, source_map)
      
      io.puts parts.join(" ")
    end
    
    private def print_token_with_indent(token : Token(T), index : Int32, 
                                       indent_level : Int32, 
                                       source_file : Hecate::Core::SourceFile,
                                       source_map : Hecate::Core::SourceMap, io : IO)
      indent = "  " * indent_level
      
      parts = [] of String
      
      # Add index
      if @show_indices
        parts << "#{index.to_s.rjust(3)}:"
      end
      
      # Add position
      if @show_positions
        pos = source_file.byte_to_position(token.span.start_byte)
        parts << "[#{pos.display_line}:#{pos.display_column.to_s.ljust(2)}]"
      end
      
      # Print with indentation
      if parts.any?
        io.print parts.join(" ")
        io.print " "
      end
      
      io.print indent
      io.puts @formatter.format(token, source_map)
    end
    
    private def is_eof?(token : Token(T)) : Bool
      # Check if token kind is EOF by name
      token.kind.to_s.upcase == "EOF"
    end
  end
  
  # Convenience method to create a token stream printer
  def self.token_printer(formatter : TokenFormatter(T)? = nil) forall T
    TokenStreamPrinter.new(formatter)
  end
end