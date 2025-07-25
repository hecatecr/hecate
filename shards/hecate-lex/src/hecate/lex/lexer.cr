require "hecate-core"
require "./token"
require "./rule"

module Hecate::Lex
  # Main lexer class that performs tokenization using defined rules
  class Lexer(T)
    @rules : Array(Rule(T))
    @error_handlers : Hash(T, Proc(String, Int32, Hecate::Core::Diagnostic))

    def initialize(rules : Array(Rule(T)), error_handlers : Hash(T, Proc(String, Int32, Hecate::Core::Diagnostic)) = {} of T => Proc(String, Int32, Hecate::Core::Diagnostic))
      # Sort rules by priority (higher priority first), then by pattern length (longer first)
      @rules = rules.sort_by { |rule| {-rule.priority, -rule.pattern.source.size} }
      @error_handlers = error_handlers
    end

    # Scan input and return tokens with diagnostics
    def scan(source_file : Hecate::Core::SourceFile) : {Array(Token(T)), Array(Hecate::Core::Diagnostic)}
      tokens = [] of Token(T)
      diagnostics = [] of Hecate::Core::Diagnostic
      input = source_file.contents
      position = 0

      while position < input.size
        match_found = false
        longest_match = nil
        longest_rule = nil

        # Find the longest matching rule at current position
        @rules.each do |rule|
          if match = input.match(rule.pattern, position)
            if match.begin == position
              # This rule matches at current position
              if longest_match.nil? || match.end > longest_match.end
                longest_match = match
                longest_rule = rule
              end
            end
          end
        end

        if longest_match && longest_rule
          # Create token with proper span
          span = Hecate::Core::Span.new(source_file.id, position, longest_match.end)
          token = Token.new(longest_rule.kind, span)

          # Add token unless it should be skipped
          unless longest_rule.skip
            tokens << token
          end

          position = longest_match.end
          match_found = true
        end

        unless match_found
          # No rule matched - this is a lexical error
          char = input[position]
          char_span = Hecate::Core::Span.new(source_file.id, position, position + 1)

          diagnostic = Hecate.error("unexpected character")
            .primary(char_span, "unexpected '#{char}'")
            .help("remove this character or add a lexer rule to handle it")
            .build

          diagnostics << diagnostic
          position += 1 # Skip the problematic character and continue
        end
      end

      {tokens, diagnostics}
    end

    # Get the rules (for inspection/debugging)
    def rules
      @rules
    end

    # Get error handlers (for inspection/debugging)
    def error_handlers
      @error_handlers
    end
  end
end
