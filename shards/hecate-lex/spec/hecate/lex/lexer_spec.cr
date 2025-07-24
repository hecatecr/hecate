require "../../spec_helper"

describe "Hecate::Lex Dynamic Lexer" do
  describe "basic tokenization" do
    it "tokenizes simple input with generated tokens" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :IDENTIFIER, /[a-zA-Z]+/
        ctx.token :NUMBER, /\d+/
        ctx.token :PLUS, /\+/
        ctx.token :WS, /\s+/, skip: true
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "hello 123 + world")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      diagnostics.should be_empty
      tokens.size.should eq(4)
      
      tokens[0].kind_name.should eq("IDENTIFIER")
      tokens[0].lexeme(source_file).should eq("hello")
      
      tokens[1].kind_name.should eq("NUMBER")
      tokens[1].lexeme(source_file).should eq("123")
      
      tokens[2].kind_name.should eq("PLUS")
      tokens[2].lexeme(source_file).should eq("+")
      
      tokens[3].kind_name.should eq("IDENTIFIER")
      tokens[3].lexeme(source_file).should eq("world")
    end

    it "skips whitespace tokens when marked" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :WORD, /\w+/
        ctx.token :WS, /\s+/, skip: true
      end

      source_map = SourceMap.new  
      source_id = source_map.add_file("test.txt", "hello   world")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      diagnostics.should be_empty
      tokens.size.should eq(2)
      tokens.map(&.lexeme(source_file)).should eq(["hello", "world"])
    end

    it "respects priority ordering" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :IDENTIFIER, /[a-zA-Z]+/
        ctx.token :IF, /if/, priority: 10  # Higher priority should match first
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "if")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      diagnostics.should be_empty
      tokens.size.should eq(1)
      tokens[0].kind_name.should eq("IF")
    end

    it "uses longest match when priorities are equal" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :A, /a/
        ctx.token :AA, /aa/  # Longer pattern should win
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "aa")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      diagnostics.should be_empty
      tokens.size.should eq(1)
      tokens[0].kind_name.should eq("AA")
    end
  end

  describe "error handling" do
    it "reports unexpected characters with diagnostics" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :LETTER, /[a-zA-Z]/
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "a@b")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      tokens.size.should eq(2)  # 'a' and 'b'
      diagnostics.size.should eq(1)
      
      diagnostic = diagnostics[0]
      diagnostic.severity.should eq(Diagnostic::Severity::Error)
      diagnostic.message.should eq("unexpected character")
      primary_label = diagnostic.labels.find(&.style.primary?)
      primary_label.not_nil!.message.should eq("unexpected '@'")
    end

    it "continues scanning after errors" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :DIGIT, /\d/
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "1@2#3")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      tokens.size.should eq(3)  # '1', '2', '3'
      diagnostics.size.should eq(2)  # '@' and '#'
      
      tokens.map(&.lexeme(source_file)).should eq(["1", "2", "3"])
    end
  end


  describe "span tracking" do
    it "creates correct spans for tokens" do
      lexer = Hecate::Lex.define do |ctx|
        ctx.token :WORD, /\w+/
        ctx.token :SPACE, /\s+/, skip: true
      end

      source_map = SourceMap.new
      source_id = source_map.add_file("test.txt", "hello world")
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      diagnostics.should be_empty
      tokens.size.should eq(2)
      
      # First token: "hello" at bytes 0-5
      tokens[0].span.start_byte.should eq(0)
      tokens[0].span.end_byte.should eq(5)
      
      # Second token: "world" at bytes 6-11
      tokens[1].span.start_byte.should eq(6)
      tokens[1].span.end_byte.should eq(11)
    end
  end
end