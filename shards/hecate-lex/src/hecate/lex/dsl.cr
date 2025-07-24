require "hecate-core"

module Hecate::Lex

  # Context class that captures DSL definitions
  private class DSLContext(T)
    getter rules = [] of Rule(T)
    getter error_handlers = {} of T => Proc(String, Int32, Hecate::Core::Diagnostic)

    def initialize(@token_enum : T.class)
    end

    # Define a token rule with optional skip flag and priority
    def token(kind : Symbol, pattern : Regex, skip : Bool = false, priority : Int32 = 0)
      # Convert symbol to enum value
      token_kind = @token_enum.parse?(kind.to_s)
      unless token_kind
        raise "Unknown token kind: #{kind}. Available kinds: #{@token_enum.names.join(", ")}"
      end

      rule = Rule.new(token_kind, pattern, skip, priority)
      @rules << rule
    end

    # Define an error handler for a specific token kind
    def error(kind : Symbol, &handler : String, Int32 -> Hecate::Core::Diagnostic)
      token_kind = @token_enum.parse?(kind.to_s)
      unless token_kind
        raise "Unknown token kind for error handler: #{kind}. Available kinds: #{@token_enum.names.join(", ")}"
      end

      @error_handlers[token_kind] = handler
    end
  end

  # Special context for dynamic token kinds
  private class DynamicDSLContext
    @symbol_to_int = {} of String => Int32
    @int_to_symbol = {} of Int32 => String
    @next_id = 0
    @rules = [] of Rule(Int32) 
    @error_handlers = {} of Int32 => Proc(String, Int32, Hecate::Core::Diagnostic)

    # Define a token rule with dynamic enum creation
    def token(kind : Symbol, pattern : Regex, skip : Bool = false, priority : Int32 = 0)
      kind_str = kind.to_s
      unless @symbol_to_int.has_key?(kind_str)
        @symbol_to_int[kind_str] = @next_id
        @int_to_symbol[@next_id] = kind_str
        @next_id += 1
      end

      token_id = @symbol_to_int[kind_str]
      rule = Rule.new(token_id, pattern, skip, priority)
      @rules << rule
    end

    # Define an error handler for dynamic token kinds
    def error(kind : Symbol, &handler : String, Int32 -> Hecate::Core::Diagnostic)
      kind_str = kind.to_s
      unless @symbol_to_int.has_key?(kind_str)
        @symbol_to_int[kind_str] = @next_id
        @int_to_symbol[@next_id] = kind_str
        @next_id += 1
      end

      token_id = @symbol_to_int[kind_str]
      @error_handlers[token_id] = handler
    end

    def build_lexer
      DynamicLexer.new(@rules, @error_handlers, @symbol_to_int, @int_to_symbol)
    end
  end

  # Lexer for dynamically defined token kinds
  class DynamicLexer
    @rules : Array(Rule(Int32))
    @error_handlers : Hash(Int32, Proc(String, Int32, Hecate::Core::Diagnostic))
    @symbol_to_int : Hash(String, Int32)
    @int_to_symbol : Hash(Int32, String)

    def initialize(@rules, @error_handlers, @symbol_to_int, @int_to_symbol)
      # Sort rules by priority (higher priority first), then by pattern length (longer first)
      @rules = @rules.sort_by { |rule| {-rule.priority, -rule.pattern.source.size} }
    end

    # Scan input and return tokens with diagnostics
    def scan(source_file : Hecate::Core::SourceFile) : {Array(DynamicToken), Array(Hecate::Core::Diagnostic)}
      tokens = [] of DynamicToken
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
          token = DynamicToken.new(longest_rule.kind, span, source_file, @int_to_symbol[longest_rule.kind])

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
          position += 1  # Skip the problematic character and continue
        end
      end

      {tokens, diagnostics}
    end

    def rules
      @rules
    end

    def error_handlers
      @error_handlers
    end
  end

  # Dynamic token for auto-generated lexers
  struct DynamicToken
    getter kind : Int32
    getter span : Hecate::Core::Span
    getter kind_name : String

    def initialize(@kind : Int32, @span : Hecate::Core::Span, @source_file : Hecate::Core::SourceFile, @kind_name : String)
    end

    def lexeme(source_file : Hecate::Core::SourceFile = @source_file) : String
      source_file.contents[@span.start_byte...@span.end_byte]
    end

    def ==(other : DynamicToken) : Bool
      @kind == other.kind && @span == other.span
    end
  end

  # Main DSL function for defining a lexer without custom enum
  def self.define(&block : DynamicDSLContext ->)
    context = DynamicDSLContext.new
    yield context
    context.build_lexer
  end

  # Main DSL function for defining a lexer with custom enum
  def self.define(token_enum : T.class, &block : DSLContext(T) ->) forall T
    context = DSLContext(T).new(token_enum)
    yield context
    Lexer(T).new(context.rules, context.error_handlers)
  end
end