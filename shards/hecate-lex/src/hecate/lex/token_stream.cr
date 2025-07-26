require "hecate-core"
require "./token"
require "./lexer"

module Hecate::Lex
  # A stream interface for tokens that provides peek/advance functionality
  #
  # TokenStream wraps an array of tokens and provides a cursor-based interface
  # for consuming tokens one at a time. It supports peeking ahead without
  # consuming tokens and pushing tokens back onto the stream.
  #
  # Example:
  # ```
  # tokens, _ = lexer.scan(source_file)
  # stream = TokenStream.new(tokens)
  #
  # while !stream.eof?
  #   token = stream.peek
  #   if token.kind == TokenKind::Identifier
  #     stream.advance
  #     # Process identifier
  #   end
  # end
  # ```
  class TokenStream(T)
    @tokens : Array(Token(T))
    @position : Int32
    @pushed_back : Array(Token(T))

    # Creates a new token stream from an array of tokens
    #
    # - *tokens*: The array of tokens to stream
    def initialize(@tokens : Array(Token(T)))
      @position = 0
      @pushed_back = [] of Token(T)
    end

    # Peeks at the current token without consuming it
    #
    # Returns the token at the current position, or raises if at EOF.
    # Multiple calls to peek return the same token until advance is called.
    #
    # Example:
    # ```
    # token = stream.peek
    # same_token = stream.peek # Returns the same token
    # ```
    def peek : Token(T)
      if @pushed_back.any?
        return @pushed_back.last
      end

      if @position >= @tokens.size
        raise "Unexpected end of token stream"
      end

      @tokens[@position]
    end

    # Peeks at a token n positions ahead without consuming any tokens
    #
    # - *n*: Number of positions to look ahead (0 = current token)
    # - Returns: The token at position + n, or nil if beyond EOF
    #
    # Example:
    # ```
    # current = stream.peek(0)   # Same as peek
    # next = stream.peek(1)      # Look ahead 1 token
    # future = stream.peek(3)    # Look ahead 3 tokens
    # ```
    def peek(n : Int32) : Token(T)?
      if @pushed_back.any?
        if n < @pushed_back.size
          return @pushed_back[@pushed_back.size - 1 - n]
        end
        n -= @pushed_back.size
      end

      pos = @position + n
      if pos >= @tokens.size
        return nil
      end

      @tokens[pos]
    end

    # Advances the stream by consuming the current token
    #
    # Returns the consumed token and moves the position forward.
    # If tokens were pushed back, consumes from the push-back stack first.
    #
    # Example:
    # ```
    # token = stream.advance # Consumes and returns current token
    # next = stream.peek     # Now points to the next token
    # ```
    def advance : Token(T)
      if @pushed_back.any?
        return @pushed_back.pop
      end

      if @position >= @tokens.size
        raise "Unexpected end of token stream"
      end

      token = @tokens[@position]
      @position += 1
      token
    end

    # Pushes a token back onto the stream
    #
    # The pushed token will be returned by the next call to peek or advance.
    # Multiple tokens can be pushed back and will be consumed in LIFO order.
    #
    # - *token*: The token to push back
    #
    # Example:
    # ```
    # token = stream.advance
    # stream.push(token)    # Put it back
    # same = stream.advance # Get it again
    # ```
    def push(token : Token(T))
      @pushed_back << token
    end

    # Checks if the stream is at the end of tokens
    #
    # Returns true if there are no more tokens to consume.
    # Takes pushed-back tokens into account.
    #
    # Example:
    # ```
    # while !stream.eof?
    #   token = stream.advance
    #   # Process token
    # end
    # ```
    def eof? : Bool
      @pushed_back.empty? && @position >= @tokens.size
    end

    # Returns the current position in the original token array
    #
    # The position is not affected by pushed-back tokens.
    # Useful for error reporting and debugging.
    #
    # Example:
    # ```
    # pos = stream.position
    # token = stream.advance
    # puts "Consumed token at position #{pos}"
    # ```
    def position : Int32
      @position
    end

    # Returns the total number of tokens in the stream
    #
    # This count includes tokens that have already been consumed
    # but does not include pushed-back tokens.
    def size : Int32
      @tokens.size
    end

    # Returns the number of remaining tokens
    #
    # Includes pushed-back tokens in the count.
    #
    # Example:
    # ```
    # puts "#{stream.remaining} tokens left to process"
    # ```
    def remaining : Int32
      @pushed_back.size + (@tokens.size - @position)
    end

    # Consumes tokens while the given block returns true
    #
    # This method advances through tokens as long as the block
    # returns true for the current token. Returns an array of
    # all consumed tokens.
    #
    # Example:
    # ```
    # # Skip all whitespace tokens
    # stream.consume_while { |token| token.kind == TokenKind::Whitespace }
    #
    # # Collect all identifier tokens
    # identifiers = stream.consume_while { |token| token.kind == TokenKind::Identifier }
    # ```
    def consume_while(&block : Token(T) -> Bool) : Array(Token(T))
      consumed = [] of Token(T)

      while !eof? && yield(peek)
        consumed << advance
      end

      consumed
    end

    # Expects the current token to have the specified kind
    #
    # If the current token matches the expected kind, it is consumed
    # and returned. Otherwise, raises an exception with details.
    #
    # - *expected_kind*: The expected token kind
    # - Returns: The consumed token
    #
    # Example:
    # ```
    # # Expect and consume an opening parenthesis
    # stream.expect(TokenKind::LeftParen)
    # ```
    def expect(expected_kind : T) : Token(T)
      if eof?
        raise "Expected #{expected_kind} but found EOF"
      end

      token = peek
      if token.kind != expected_kind
        raise "Expected #{expected_kind} but found #{token.kind}"
      end

      advance
    end

    # Tries to match and consume a token of the specified kind
    #
    # If the current token matches, it is consumed and returned.
    # If not, returns nil without consuming anything.
    #
    # - *kind*: The token kind to match
    # - Returns: The consumed token, or nil if no match
    #
    # Example:
    # ```
    # if token = stream.try_match(TokenKind::Semicolon)
    #   # Optional semicolon was present
    # end
    # ```
    def try_match(kind : T) : Token(T)?
      return nil if eof?

      if peek.kind == kind
        advance
      else
        nil
      end
    end
  end
end
