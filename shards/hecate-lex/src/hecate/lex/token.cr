# Token data structure for lexical analysis
#
# The Token struct represents a lexical token with its kind, source location,
# and optional semantic value. It uses generics to provide compile-time type
# safety for token kinds while maintaining efficient memory usage.

module Hecate::Lex
  # Represents a lexical token with kind, span, and optional semantic value
  #
  # The Token struct is generic over the token kind type T, which should
  # typically be an enum representing the different token types in your language.
  # This provides compile-time type safety and helps catch token kind mismatches.
  #
  # Example:
  # ```
  # enum MyTokenKind
  #   Identifier
  #   Integer
  #   Plus
  # end
  #
  # token = Token.new(MyTokenKind::Integer, span, "42")
  # ```
  struct Token(T)
    # The kind/type of this token (typically an enum value)
    getter kind : T

    # The source location of this token
    getter span : Hecate::Core::Span

    # Optional semantic value (used for caching or when source is unavailable)
    getter value : String?

    # Creates a new token with the specified kind, span, and optional value
    #
    # - *kind*: The token kind (typically an enum value)
    # - *span*: The source location of this token
    # - *value*: Optional semantic value for the token
    def initialize(@kind : T, @span : Hecate::Core::Span, @value : String? = nil)
    end

    # Lazily retrieves the lexeme (token text) from the source map
    #
    # This method extracts the actual text represented by this token from
    # the source file using the token's span. It falls back to the stored
    # value or a placeholder if the source is not available.
    #
    # - *source_map*: The source map containing the source files
    # - Returns: The token's lexeme as a string
    #
    # Example:
    # ```
    # token = Token.new(TokenKind::Integer, span)
    # lexeme = token.lexeme(source_map) # => "42"
    # ```
    def lexeme(source_map : Hecate::Core::SourceMap) : String
      if source = source_map.get(@span.source_id)
        source.contents[@span.start_byte...@span.end_byte]
      else
        @value || "<unknown>"
      end
    end

    # Compares two tokens for equality based on kind and span
    #
    # Two tokens are considered equal if they have the same kind and span.
    # The optional value field is intentionally excluded from equality
    # comparison to ensure consistent behavior regardless of whether the
    # lexeme was cached or not.
    #
    # - *other*: The other token to compare with
    # - Returns: true if the tokens are equal, false otherwise
    #
    # Example:
    # ```
    # token1 = Token.new(TokenKind::Integer, span1)
    # token2 = Token.new(TokenKind::Integer, span1)
    # token1 == token2 # => true
    # ```
    def ==(other : Token(T)) : Bool
      @kind == other.kind && @span == other.span
    end
  end
end
