module Hecate::Lex
  # Utility for formatting tokens for display
  #
  # Provides customizable formatting for tokens, including:
  # - Showing lexemes for literal tokens
  # - Truncating long lexemes
  # - Custom formatting rules per token type
  #
  # Example:
  # ```
  # formatter = TokenFormatter.new(format_literals: true, max_lexeme_length: 30)
  # formatted = formatter.format(token, source_map)
  # puts formatted # => "STRING(\"hello world\")"
  # ```
  class TokenFormatter(T)
    # Whether to show lexemes for literal tokens
    getter format_literals : Bool
    
    # Maximum length for displayed lexemes before truncation
    getter max_lexeme_length : Int32
    
    # Token types that should show their lexeme
    getter literal_types : Set(T)
    
    # Custom format handlers for specific token types
    getter custom_handlers : Hash(T, Proc(Token(T), String, String))
    
    def initialize(@format_literals = true, @max_lexeme_length = 50, @literal_types = Set(T).new)
      @custom_handlers = {} of T => Proc(Token(T), String, String)
    end
    
    # Add a token type that should display its lexeme
    def add_literal_type(type : T)
      @literal_types << type
      self
    end
    
    # Add multiple token types that should display their lexemes
    def add_literal_types(*types : T)
      types.each { |type| @literal_types << type }
      self
    end
    
    # Set a custom formatter for a specific token type
    def set_custom_handler(type : T, &handler : Token(T), String -> String)
      @custom_handlers[type] = handler
      self
    end
    
    # Format a token for display
    def format(token : Token(T), source_map : Hecate::Core::SourceMap) : String
      # Check for custom handler first
      if handler = @custom_handlers[token.kind]?
        lexeme = token.lexeme(source_map)
        return handler.call(token, lexeme)
      end
      
      # Standard formatting
      if @format_literals && should_show_lexeme?(token)
        lexeme = token.lexeme(source_map)
        formatted_lexeme = format_lexeme(lexeme)
        "#{token.kind}(#{formatted_lexeme})"
      else
        token.kind.to_s
      end
    end
    
    # Format a token with position information
    def format_with_position(token : Token(T), source_file : Hecate::Core::SourceFile) : String
      pos = source_file.byte_to_position(token.span.start_byte)
      line = pos.display_line
      col = pos.display_column
      
      formatted = format(token, source_file.source_map)
      "[#{line}:#{col}] #{formatted}"
    end
    
    private def should_show_lexeme?(token : Token(T)) : Bool
      return true if @literal_types.includes?(token.kind)
      
      # Check if token kind name suggests it's a literal
      # This is a heuristic for when literal_types isn't configured
      kind_name = token.kind.to_s.downcase
      kind_name.includes?("string") ||
      kind_name.includes?("number") ||
      kind_name.includes?("identifier") ||
      kind_name.includes?("id") ||
      kind_name.includes?("num") ||
      kind_name.includes?("str") ||
      kind_name.includes?("literal")
    end
    
    private def format_lexeme(lexeme : String) : String
      if lexeme.size > @max_lexeme_length
        truncated = lexeme[0...(@max_lexeme_length - 3)] + "..."
        truncated.inspect
      else
        lexeme.inspect
      end
    end
  end
  
  # Convenience method to create a token formatter with common literal types
  def self.token_formatter(*literal_types : T) forall T
    formatter = TokenFormatter(T).new
    formatter.add_literal_types(*literal_types)
    formatter
  end
end