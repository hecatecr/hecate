require "../../spec_helper"

enum CustomTokens
  WORD
  NUMBER
  SPACE
  PLUS
end

describe "Hecate::Lex Typed Lexer" do
  describe "with custom token enum" do
    it "works with predefined token enum" do
      lexer = Hecate::Lex.define(CustomTokens) do |ctx|
        ctx.token :WORD, /[a-zA-Z]+/
        ctx.token :NUMBER, /\d+/
        ctx.token :SPACE, /\s+/, skip: true
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "hello 123")
      source_file = source_map.get(source_id).not_nil!

      tokens, diagnostics = lexer.scan(source_file)

      diagnostics.should be_empty
      tokens.size.should eq(2)
      tokens[0].kind.should eq(CustomTokens::WORD)
      tokens[1].kind.should eq(CustomTokens::NUMBER)
    end

    it "handles priority with typed tokens" do
      lexer = Hecate::Lex.define(CustomTokens) do |ctx|
        ctx.token :WORD, /\w+/
        ctx.token :NUMBER, /\d+/, priority: 5
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "123")
      source_file = source_map.get(source_id).not_nil!

      tokens, diagnostics = lexer.scan(source_file)

      diagnostics.should be_empty
      tokens.size.should eq(1)
      tokens[0].kind.should eq(CustomTokens::NUMBER)
    end

    it "raises error for unknown token kind" do
      expect_raises(Exception, /Unknown token kind: INVALID/) do
        Hecate::Lex.define(CustomTokens) do |ctx|
          ctx.token :INVALID, /test/
        end
      end
    end

    it "supports error handlers with typed tokens" do
      lexer = Hecate::Lex.define(CustomTokens) do |ctx|
        ctx.token :WORD, /\w+/

        ctx.error :WORD do |input, pos|
          Hecate.error("word error")
            .primary(Span.new(0_u32, pos, input.size), "word issue")
            .build
        end
      end

      lexer.error_handlers.size.should eq(1)
      lexer.error_handlers.has_key?(CustomTokens::WORD).should be_true
    end
  end
end
