require "../../spec_helper"

enum MyTokens
  WORD
  DIGIT
end

enum TestTokens
  VALID
end

describe "Hecate::Lex DSL" do
  describe "define function" do
    it "creates lexer with generated token enum" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :IDENTIFIER, /[a-zA-Z]+/
        ctx.token :NUMBER, /\d+/
      end

      lexer.should be_a(Hecate::Lex::DynamicLexer)
      lexer.rules.size.should eq(2)
    end

    it "creates lexer with custom token enum" do
      lexer = Hecate::Lex.define(MyTokens) do |ctx|
        ctx.token :WORD, /[a-zA-Z]+/
        ctx.token :DIGIT, /\d/
      end

      lexer.should be_a(Hecate::Lex::Lexer(MyTokens))
      lexer.rules.size.should eq(2)
    end

    it "supports skip flag" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :WORD, /\w+/
        ctx.token :WS, /\s+/, skip: true
      end

      # Check that WS rule is marked as skip
      ws_rule = lexer.rules.find { |r| r.pattern.source == "\\s+" }
      ws_rule.should_not be_nil
      ws_rule.not_nil!.skip.should be_true
    end

    it "supports priority settings" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :GENERIC, /\w+/
        ctx.token :SPECIFIC, /if/, priority: 10
      end

      # Rules should be sorted by priority (highest first)
      lexer.rules[0].priority.should eq(10)
      lexer.rules[1].priority.should eq(0)
    end
  end

  describe "token method" do
    it "raises error for invalid token kind" do
      expect_raises(Exception, /Unknown token kind: invalid/) do
        Hecate::Lex.define(TestTokens) do |ctx|
          ctx.token :invalid, /test/
        end
      end
    end
  end

  describe "error method" do  
    it "registers error handlers" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :STRING, /"[^"]*"/
        
        ctx.error :UNTERMINATED_STRING do |input, pos|
          Hecate.error("unterminated string")
            .primary(Span.new(0_u32, pos, input.size), "string starts here")
            .build
        end
      end

      lexer.error_handlers.size.should eq(1)
    end

    it "raises error for invalid error handler token kind" do
      expect_raises(Exception, /Unknown token kind for error handler: invalid/) do
        Hecate::Lex.define(TestTokens) do |ctx|
          ctx.error :invalid do |input, pos|
            Hecate.error("test").build
          end
        end
      end
    end
  end

  describe "integration" do
    it "creates working lexer from DSL" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :IF, /if/
        ctx.token :ELSE, /else/
        ctx.token :IDENTIFIER, /[a-zA-Z_]\w*/
        ctx.token :NUMBER, /\d+/
        ctx.token :PLUS, /\+/
        ctx.token :MINUS, /-/
        ctx.token :LPAREN, /\(/
        ctx.token :RPAREN, /\)/
        ctx.token :WS, /\s+/, skip: true
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "if (x + 1) else y")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      diagnostics.should be_empty
      tokens.size.should eq(8)
      
      expected_lexemes = ["if", "(", "x", "+", "1", ")", "else", "y"]
      actual_lexemes = tokens.map(&.lexeme(source_file))
      actual_lexemes.should eq(expected_lexemes)
    end
  end
end