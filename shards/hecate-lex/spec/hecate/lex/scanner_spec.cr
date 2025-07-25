require "../../spec_helper"

# Test token enum for Scanner tests
enum ScannerTokens
  WORD
  NUMBER
  PLUS
  SPACE
  EOF
end

describe Hecate::Lex::Scanner do
  describe "initialization" do
    it "creates scanner with rule set and source map" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /[a-zA-Z]+/))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      scanner.should be_a(Hecate::Lex::Scanner(ScannerTokens))
    end

    it "raises on invalid source ID" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      source_map = Hecate::Core::SourceMap.new

      expect_raises(NilAssertionError) do
        Hecate::Lex::Scanner.new(rule_set, 999_u32, source_map)
      end
    end
  end

  describe "longest-match-wins algorithm" do
    it "prefers longer matches over shorter ones" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /a/))
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::NUMBER, /aa/))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "aa")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      diagnostics.should be_empty
      tokens.size.should eq(2) # NUMBER + EOF
      tokens[0].kind.should eq(ScannerTokens::NUMBER)
    end

    it "uses priority for equal-length matches" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /if/, priority: 1))
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::NUMBER, /if/, priority: 10))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "if")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      diagnostics.should be_empty
      tokens.size.should eq(2) # NUMBER (higher priority) + EOF
      tokens[0].kind.should eq(ScannerTokens::NUMBER)
    end
  end

  describe "skip rules" do
    it "skips tokens marked with skip flag" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /[a-zA-Z]+/))
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::SPACE, /\s+/, skip: true))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello   world")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      diagnostics.should be_empty
      tokens.size.should eq(3) # hello, world, EOF
      tokens[0].kind.should eq(ScannerTokens::WORD)
      tokens[1].kind.should eq(ScannerTokens::WORD)
      tokens[2].kind.should eq(ScannerTokens::EOF)
    end
  end

  describe "error recovery" do
    it "handles unmatched input with diagnostics" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /[a-zA-Z]/))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "a@b")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      tokens.size.should eq(3) # a, b, EOF
      diagnostics.size.should eq(1)

      diagnostic = diagnostics[0]
      diagnostic.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      diagnostic.message.should eq("unexpected character")

      primary_label = diagnostic.labels.find(&.style.primary?)
      primary_label.not_nil!.message.should eq("unexpected '@'")
    end

    it "continues scanning after errors" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::NUMBER, /\d/))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "1@2#3")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      tokens.size.should eq(4)      # 1, 2, 3, EOF
      diagnostics.size.should eq(2) # @ and #

      tokens[0].kind.should eq(ScannerTokens::NUMBER)
      tokens[1].kind.should eq(ScannerTokens::NUMBER)
      tokens[2].kind.should eq(ScannerTokens::NUMBER)
      tokens[3].kind.should eq(ScannerTokens::EOF)
    end
  end

  describe "EOF token" do
    it "always adds EOF token at end" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /\w+/))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      tokens.last.kind.should eq(ScannerTokens::EOF)
      tokens.last.span.start_byte.should eq(5)
      tokens.last.span.end_byte.should eq(5)
    end

    it "adds EOF token for empty input" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      tokens.size.should eq(1)
      tokens[0].kind.should eq(ScannerTokens::EOF)
      tokens[0].span.start_byte.should eq(0)
      tokens[0].span.end_byte.should eq(0)
    end
  end

  describe "span tracking" do
    it "creates correct spans for tokens" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /\w+/))
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::SPACE, /\s+/, skip: true))

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello world")

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      tokens, diagnostics = scanner.scan_all

      diagnostics.should be_empty
      tokens.size.should eq(3) # hello, world, EOF

      # First token: "hello" at bytes 0-5
      tokens[0].span.start_byte.should eq(0)
      tokens[0].span.end_byte.should eq(5)

      # Second token: "world" at bytes 6-11
      tokens[1].span.start_byte.should eq(6)
      tokens[1].span.end_byte.should eq(11)
    end
  end

  describe "performance characteristics" do
    it "handles large input efficiently" do
      rule_set = Hecate::Lex::RuleSet(ScannerTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::WORD, /\w+/))
      rule_set.add_rule(Hecate::Lex::Rule.new(ScannerTokens::SPACE, /\s+/, skip: true))

      # Create a large input string
      large_input = (["word"] * 1000).join(" ")

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("large.txt", large_input)

      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)

      tokens, diagnostics = scanner.scan_all

      # Should complete successfully without errors
      diagnostics.should be_empty
      tokens.size.should eq(1001) # 1000 words + EOF
    end
  end
end
