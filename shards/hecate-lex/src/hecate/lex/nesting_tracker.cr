module Hecate::Lex
  # Utility for tracking nesting levels of paired tokens
  #
  # Useful for pretty-printing structured formats like JSON, XML, or code
  # with proper indentation based on nesting depth.
  #
  # Example:
  # ```
  # tracker = NestingTracker.new(
  #   open_tokens: [JSONTokens::LBRACE, JSONTokens::LBRACKET],
  #   close_tokens: [JSONTokens::RBRACE, JSONTokens::RBRACKET]
  # )
  #
  # tokens.each do |token|
  #   indent_level = tracker.process(token.kind)
  #   puts "  " * indent_level + format_token(token)
  # end
  #
  # if tracker.balanced?
  #   puts "All brackets balanced!"
  # end
  # ```
  class NestingTracker(T)
    # Current nesting level
    getter level : Int32

    # Stack of opening tokens for validation
    getter stack : Array(T)

    # Tokens that increase nesting level
    getter open_tokens : Set(T)

    # Tokens that decrease nesting level
    getter close_tokens : Set(T)

    # Map of close tokens to their corresponding open tokens (for validation)
    getter pairs : Hash(T, T)?

    # Track if we've seen too many closing tokens
    getter extra_closing_tokens : Int32

    def initialize(open_tokens : Array(T), close_tokens : Array(T), @pairs : Hash(T, T)? = nil)
      @open_tokens = open_tokens.to_set
      @close_tokens = close_tokens.to_set
      @level = 0
      @stack = [] of T
      @extra_closing_tokens = 0
    end

    # Process a token and return the nesting level to use for display
    #
    # For opening tokens, returns the current level (before incrementing)
    # For closing tokens, decrements first then returns the new level
    # For other tokens, returns the current level
    def process(token : T) : Int32
      if @open_tokens.includes?(token)
        current = @level
        @level += 1
        @stack << token
        current
      elsif @close_tokens.includes?(token)
        # Validate pairing if pairs are defined
        if pairs = @pairs
          expected_open = pairs[token]?

          if @level == 0
            # No opens left, this is an extra closing token
            @extra_closing_tokens += 1
          elsif @stack.any? && expected_open && @stack.last != expected_open
            # Mismatched closing token - treat as extra and don't change level
            @extra_closing_tokens += 1
          else
            # Valid close - decrement level and pop stack
            @level -= 1
            @stack.pop unless @stack.empty?
          end
        else
          # No pairs defined, simple level tracking
          if @level > 0
            @level -= 1
            @stack.pop unless @stack.empty?
          else
            @extra_closing_tokens += 1
          end
        end

        @level
      else
        @level
      end
    end

    # Check if all opened tokens have been properly closed
    def balanced? : Bool
      @stack.empty? && @level == 0 && @extra_closing_tokens == 0
    end

    # Get any unclosed tokens
    def unclosed_tokens : Array(T)
      @stack.dup
    end

    # Reset the tracker to initial state
    def reset
      @level = 0
      @stack.clear
      @extra_closing_tokens = 0
    end

    # Get a validation error message if unbalanced
    def validation_error : String?
      return nil if balanced?

      if @extra_closing_tokens > 0
        "Too many closing tokens (#{@extra_closing_tokens} extra)"
      elsif @level > 0
        "Unclosed tokens: #{@stack.map(&.to_s).join(", ")}"
      else
        "Mismatched tokens in stack: #{@stack.map(&.to_s).join(", ")}"
      end
    end
  end

  # Convenience method to create a nesting tracker for common bracket pairs
  def self.bracket_tracker(brace_open : T, brace_close : T,
                           bracket_open : T, bracket_close : T,
                           paren_open : T? = nil, paren_close : T? = nil) forall T
    open_tokens = [brace_open, bracket_open]
    close_tokens = [brace_close, bracket_close]
    pairs = {
      brace_close   => brace_open,
      bracket_close => bracket_open,
    }

    if paren_open && paren_close
      open_tokens << paren_open
      close_tokens << paren_close
      pairs[paren_close] = paren_open
    end

    NestingTracker.new(open_tokens, close_tokens, pairs)
  end
end
