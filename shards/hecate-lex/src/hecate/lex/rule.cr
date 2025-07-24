# Rule types for lexical analysis
#
# This module provides the core rule structures used by the lexer to define
# token patterns, matching behavior, and error handling strategies.

module Hecate::Lex
  # Type alias for error handler functions
  #
  # Error handlers are called when a pattern fails to match and need to
  # generate appropriate diagnostics. They receive the input text and
  # current position where the error occurred. They return a DiagnosticBuilder
  # that can be further customized before being built into a final Diagnostic.
  alias ErrorHandler = Proc(String, Int32, Hecate::Core::DiagnosticBuilder)

  # A lexer rule that defines how to match a specific token type
  #
  # Rules contain the pattern to match, metadata about the token kind,
  # and optional configuration for priority and error handling.
  #
  # Example:
  # ```
  # rule = Rule.new(TokenKind::Integer, /\d+/, priority: 10)
  # rule = Rule.new(TokenKind::Whitespace, /\s+/, skip: true)
  # ```
  struct Rule(T)
    # The token kind this rule produces
    getter kind : T
    
    # The regex pattern to match against
    getter pattern : Regex
    
    # Whether tokens from this rule should be skipped in output
    getter skip : Bool
    
    # Priority for conflict resolution (higher = more important)
    getter priority : Int32
    
    # Optional error handler for this rule
    getter error_handler : Symbol?

    # Creates a new lexer rule
    #
    # - *kind*: The token kind this rule produces
    # - *pattern*: String or Regex pattern to match
    # - *skip*: Whether to skip tokens from this rule (default: false)
    # - *priority*: Priority for conflict resolution (default: 0)
    # - *error_handler*: Optional error handler symbol (default: nil)
    def initialize(@kind : T, pattern : String | Regex, 
                   @skip = false, @priority = 0, @error_handler = nil)
      @pattern = pattern.is_a?(String) ? Regex.new(pattern) : pattern
    end

    # Attempts to match this rule's pattern at a specific position in the text
    #
    # This method uses the original pattern and validates that the match starts
    # at the exact position specified for precise token boundary detection.
    #
    # - *text*: The input text to match against
    # - *pos*: The position in the text to start matching from
    # - Returns: MatchData if the pattern matches, nil otherwise
    #
    # Performance optimized: avoids creating new regex objects in hot path
    #
    # Example:
    # ```
    # rule = Rule.new(TokenKind::Integer, /\d+/)
    # match = rule.match_at("abc123def", 3) # matches "123"
    # ```
    def match_at(text : String, pos : Int32) : Regex::MatchData?
      return nil if pos >= text.size
      
      # Performance optimization: use original pattern and check match position
      # instead of creating new anchored regex each time
      if match = @pattern.match(text, pos)
        # Only return match if it starts exactly at the requested position
        if match.begin == pos
          return match
        end
      end
      
      nil
    end
  end

  # A collection of lexer rules with priority ordering and error handling
  #
  # RuleSet manages all the rules for a lexer, maintaining them in priority
  # order for efficient longest-match-wins resolution. It also manages
  # error handlers that can be referenced by rules.
  #
  # Example:
  # ```
  # rule_set = RuleSet(TokenKind).new
  # rule_set.add_rule(Rule.new(TokenKind::Integer, /\d+/, priority: 10))
  # rule_set.add_rule(Rule.new(TokenKind::Identifier, /\w+/, priority: 1))
  # ```
  class RuleSet(T)
    # Array of rules sorted by priority (highest first)
    getter rules : Array(Rule(T))
    
    # Hash of registered error handlers
    getter error_handlers : Hash(Symbol, LexErrorHandler)

    # Creates a new empty rule set
    def initialize
      @rules = [] of Rule(T)
      @error_handlers = {} of Symbol => LexErrorHandler
      register_default_error_handlers
    end
    
    # Registers the default common error handlers
    private def register_default_error_handlers
      @error_handlers[:unterminated_string] = CommonErrors::UNTERMINATED_STRING
      @error_handlers[:unterminated_comment] = CommonErrors::UNTERMINATED_COMMENT
      @error_handlers[:invalid_escape] = CommonErrors::INVALID_ESCAPE
      @error_handlers[:invalid_number] = CommonErrors::INVALID_NUMBER
      @error_handlers[:invalid_character] = CommonErrors::INVALID_CHARACTER
    end

    # Adds a rule to the rule set and sorts by priority
    #
    # Rules are automatically sorted by priority in descending order
    # (highest priority first) to implement longest-match-wins behavior.
    # When multiple rules could match at the same position, the rule
    # with higher priority takes precedence.
    #
    # Performance optimization: rules are also sub-sorted by pattern complexity
    # to put simpler/faster patterns first within the same priority group.
    #
    # - *rule*: The rule to add to the set
    #
    # Example:
    # ```
    # rule_set.add_rule(Rule.new(TokenKind::Keyword, /if/, priority: 10))
    # rule_set.add_rule(Rule.new(TokenKind::Identifier, /\w+/, priority: 1))
    # # Keywords will be checked before identifiers
    # ```
    def add_rule(rule : Rule(T))
      @rules << rule
      # Performance optimization: sort by priority (desc), then by pattern simplicity (asc)
      # This puts high-priority simple patterns first for faster matching
      @rules.sort_by! { |r| {-r.priority, r.pattern.source.size} }
    end

    # Registers an error handler with the given symbol
    #
    # Error handlers can be referenced by rules to provide custom
    # error recovery and diagnostic generation when patterns fail.
    #
    # - *symbol*: The symbol to register the handler under
    # - *handler*: The error handler
    #
    # Example:
    # ```
    # handler = LexErrorHandler.new("unterminated string", "close with matching quote")
    # rule_set.register_error_handler(:unterminated_string, handler)
    # ```
    def register_error_handler(symbol : Symbol, handler : LexErrorHandler)
      @error_handlers[symbol] = handler
    end

    # Registers an error handler with message and optional help
    #
    # Convenience method for registering error handlers with inline values.
    #
    # - *symbol*: The symbol to register the handler under
    # - *message*: The error message
    # - *help*: Optional help text
    def register_error_handler(symbol : Symbol, message : String, help : String? = nil)
      @error_handlers[symbol] = LexErrorHandler.new(message, help)
    end

    # Retrieves a registered error handler by symbol
    #
    # - *symbol*: The symbol of the error handler to retrieve
    # - Returns: The error handler, or nil if not found
    #
    # Example:
    # ```
    # handler = rule_set.get_error_handler(:unterminated_string)
    # if handler
    #   puts handler.message
    # end
    # ```
    def get_error_handler(symbol : Symbol) : LexErrorHandler?
      @error_handlers[symbol]?
    end

    # Checks if an error handler is registered for the given symbol
    #
    # - *symbol*: The symbol to check for
    # - Returns: true if the handler exists, false otherwise
    def has_error_handler?(symbol : Symbol) : Bool
      @error_handlers.has_key?(symbol)
    end
  end
end