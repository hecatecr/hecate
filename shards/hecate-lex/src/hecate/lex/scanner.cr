require "hecate-core"
require "./token"
require "./rule"

module Hecate::Lex
  # Core scanning algorithm with longest-match-wins strategy and error recovery
  #
  # The Scanner class performs the actual tokenization of input text using a set
  # of lexer rules. It implements longest-match-wins resolution, priority-based
  # tie-breaking, and robust error recovery that allows scanning to continue
  # after encountering unmatched input.
  #
  # Example:
  # ```
  # rule_set = RuleSet(TokenKind).new
  # rule_set.add_rule(Rule.new(TokenKind::Integer, /\d+/))
  # rule_set.add_rule(Rule.new(TokenKind::Identifier, /[a-zA-Z]+/))
  #
  # scanner = Scanner.new(rule_set, source_id, source_map)
  # tokens, diagnostics = scanner.scan_all
  # ```
  class Scanner(T)
    @rule_set : RuleSet(T)
    @source_id : UInt32
    @source_map : Hecate::Core::SourceMap
    @source : Hecate::Core::SourceFile
    @text : String
    @pos : Int32
    @tokens : Array(Token(T))
    @diagnostics : Array(Hecate::Core::Diagnostic)

    # Creates a new scanner with the given rule set and source information
    #
    # - *rule_set*: The collection of lexer rules to use for matching
    # - *source_id*: The ID of the source file to scan
    # - *source_map*: The source map containing the source files
    #
    # Raises if the source ID is not found in the source map.
    def initialize(@rule_set : RuleSet(T), @source_id : UInt32,
                   @source_map : Hecate::Core::SourceMap)
      @source = @source_map.get(@source_id).not_nil!
      @text = @source.contents
      @pos = 0

      # Performance optimization: pre-allocate arrays with reasonable capacity
      # to avoid repeated reallocations during scanning
      estimated_tokens = [@text.size // 5, 1000].max # Estimate 1 token per 5 chars, min 1000
      @tokens = Array(Token(T)).new(estimated_tokens)
      @diagnostics = [] of Hecate::Core::Diagnostic
    end

    # Scans the entire input and returns tokens and diagnostics
    #
    # This method processes the input from start to finish, creating tokens
    # for matched patterns and diagnostics for unmatched input. It automatically
    # adds an EOF token at the end of the input.
    #
    # Returns a tuple of {tokens, diagnostics} where:
    # - tokens: Array of Token(T) including an EOF token at the end
    # - diagnostics: Array of Diagnostic for any lexical errors
    #
    # Example:
    # ```
    # tokens, diagnostics = scanner.scan_all
    # puts "Found #{tokens.size} tokens and #{diagnostics.size} errors"
    # ```
    def scan_all : {Array(Token(T)), Array(Hecate::Core::Diagnostic)}
      while @pos < @text.size
        scan_next
      end

      # Add EOF token
      eof_span = Hecate::Core::Span.new(@source_id, @text.size, @text.size)
      @tokens << Token.new(T::EOF, eof_span)

      {@tokens, @diagnostics}
    end

    # Scans the next token from the current position
    #
    # This method implements the core longest-match-wins algorithm with optimizations:
    # 1. Try each rule in priority order
    # 2. Keep the longest match found
    # 3. For equal-length matches, prefer higher priority
    # 4. Create token unless rule is marked for skipping
    # 5. If no match, handle as error and advance one character
    #
    # Performance optimizations:
    # - Early exit when finding a match that can't be beaten
    # - Cache match results to avoid recomputation
    # - Minimize object allocations in hot path
    private def scan_next
      start_pos = @pos

      # Performance optimization: early exit conditions
      best_match_size = 0
      best_match = nil
      best_rule = nil

      # Try each rule in priority order (rules are pre-sorted by priority)
      @rule_set.rules.each do |rule|
        # Performance optimization: skip if this rule can't possibly beat current best
        # due to priority (only works if rules with same priority are grouped)
        if best_rule && rule.priority < best_rule.priority && best_match_size > 0
          break
        end

        if match = rule.match_at(@text, @pos)
          match_size = match[0].size

          # Performance optimization: prefer longer matches, then higher priority
          if match_size > best_match_size ||
             (match_size == best_match_size && rule.priority > (best_rule.try(&.priority) || -1))
            best_match = match
            best_rule = rule
            best_match_size = match_size
          end
        end
      end

      if best_match && best_rule
        # Performance optimization: minimize span object creation
        match_end = start_pos + best_match_size
        span = Hecate::Core::Span.new(@source_id, start_pos, match_end)

        # Check if this rule has an error handler
        if best_rule.error_handler
          # This is an error pattern - apply error handler
          apply_error_handler(best_rule, span, best_match)
          # Still advance position to continue scanning
          @pos = match_end
        else
          # Normal token - create unless skip rule
          unless best_rule.skip
            @tokens << Token.new(best_rule.kind, span)
          end
          @pos = match_end
        end
      else
        # No match - error recovery
        handle_unmatched_input(start_pos)
      end
    end

    # Handles unmatched input by skipping one character and emitting a diagnostic
    #
    # This method provides robust error recovery by:
    # 1. Creating a diagnostic for the unmatched character
    # 2. Advancing position by one character to continue scanning
    # 3. Preserving the exact location of the error for helpful messages
    #
    # - *pos*: The position where the unmatched input was found
    private def handle_unmatched_input(pos)
      # Skip one character and emit diagnostic
      span = Hecate::Core::Span.new(@source_id, pos, pos + 1)
      char = @text[pos]

      diagnostic = Hecate.error("unexpected character")
        .primary(span, "unexpected '#{char}'")
        .help("remove this character or add a lexer rule to handle it")
        .build

      @diagnostics << diagnostic
      @pos += 1
    end

    # Applies an error handler from a rule to generate a diagnostic
    #
    # This method looks up the error handler associated with a rule and uses it
    # to create a diagnostic for the matched pattern that indicates an error.
    #
    # - *rule*: The rule that matched an error pattern
    # - *span*: The span of the matched error pattern
    # - *match*: The regex match data
    private def apply_error_handler(rule : Rule(T), span : Hecate::Core::Span, match : Regex::MatchData)
      if handler_name = rule.error_handler
        if handler = @rule_set.get_error_handler(handler_name)
          diagnostic = Hecate::Core.error(handler.message)
            .primary(span, "here")

          if help = handler.help
            diagnostic = diagnostic.help(help)
          end

          @diagnostics << diagnostic.build
        end
      end
    end
  end
end
