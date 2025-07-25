module Hecate::Lex
  struct LexErrorHandler
    getter message : String
    getter help : String?

    def initialize(@message, @help = nil)
    end
  end

  module CommonErrors
    UNTERMINATED_STRING = LexErrorHandler.new(
      "unterminated string literal",
      "strings must be closed with a matching quote"
    )

    UNTERMINATED_COMMENT = LexErrorHandler.new(
      "unterminated block comment",
      "block comments must be closed with */"
    )

    INVALID_ESCAPE = LexErrorHandler.new(
      "invalid escape sequence",
      "valid escape sequences are: \\n \\r \\t \\\\ \\\""
    )

    INVALID_NUMBER = LexErrorHandler.new(
      "invalid number literal",
      "numbers must be in a valid format (e.g., 123, 0x7F, 3.14)"
    )

    INVALID_CHARACTER = LexErrorHandler.new(
      "invalid character",
      "this character is not allowed in this context"
    )
  end
end
