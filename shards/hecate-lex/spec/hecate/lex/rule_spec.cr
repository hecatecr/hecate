require "../../spec_helper"

# Test token kind enum for rule testing
enum RuleTestTokenKind
  Keyword
  Identifier
  Integer
  Whitespace
  String
  Plus
  Minus
  EOF
end

describe Hecate::Lex::Rule do
  describe "initialization" do
    it "creates rule with string pattern" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Keyword, "if")
      
      rule.kind.should eq(RuleTestTokenKind::Keyword)
      rule.pattern.should be_a(Regex)
      rule.skip.should be_false
      rule.priority.should eq(0)
      rule.error_handler.should be_nil
    end

    it "creates rule with regex pattern" do
      regex = /\d+/
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, regex)
      
      rule.kind.should eq(RuleTestTokenKind::Integer)
      rule.pattern.should eq(regex)
      rule.skip.should be_false
      rule.priority.should eq(0)
      rule.error_handler.should be_nil
    end

    it "creates rule with all options" do
      rule = Hecate::Lex::Rule.new(
        RuleTestTokenKind::Whitespace, 
        /\s+/, 
        skip: true, 
        priority: 5, 
        error_handler: :whitespace_error
      )
      
      rule.kind.should eq(RuleTestTokenKind::Whitespace)
      rule.skip.should be_true
      rule.priority.should eq(5)
      rule.error_handler.should eq(:whitespace_error)
    end

    it "converts string patterns to regex" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Keyword, "if")
      rule.pattern.source.should eq("if")
    end
  end

  describe "match_at method" do
    it "matches pattern at beginning of string" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      match = rule.match_at("123abc", 0)
      
      match.should_not be_nil
      match.not_nil![0].should eq("123")
    end

    it "matches pattern at middle of string" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      match = rule.match_at("abc123def", 3)
      
      match.should_not be_nil
      match.not_nil![0].should eq("123")
    end

    it "matches pattern at end of string" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      match = rule.match_at("abc123", 3)
      
      match.should_not be_nil
      match.not_nil![0].should eq("123")
    end

    it "returns nil when pattern doesn't match" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      match = rule.match_at("abcdef", 0)
      
      match.should be_nil
    end

    it "returns nil when position is beyond string length" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      match = rule.match_at("abc", 5)
      
      match.should be_nil
    end

    it "returns nil when position equals string length" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      match = rule.match_at("abc", 3)
      
      match.should be_nil
    end

    it "matches only at specified position" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      # Pattern exists at position 0 but we're matching at position 1 
      # At position 1, we should match "23"
      match = rule.match_at("123abc", 1)
      
      match.should_not be_nil
      match.not_nil![0].should eq("23")
    end

    it "doesn't match when pattern doesn't start at position" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      # At position 1 in "ab123", we have "b123" which doesn't start with digit
      match = rule.match_at("ab123", 1)
      
      match.should be_nil
    end

    it "handles complex regex patterns" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Identifier, /[a-zA-Z_]\w*/)
      match = rule.match_at("_var123 = 42", 0)
      
      match.should_not be_nil
      match.not_nil![0].should eq("_var123")
    end

    it "preserves regex options" do
      case_insensitive_regex = /if/i
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Keyword, case_insensitive_regex)
      
      # Should match uppercase
      match = rule.match_at("IF then", 0)
      match.should_not be_nil
      match.not_nil![0].should eq("IF")
    end

    it "handles empty matches" do
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::EOF, //)
      match = rule.match_at("abc", 0)
      
      match.should_not be_nil
      match.not_nil![0].should eq("")
    end
  end
end

describe Hecate::Lex::RuleSet do
  describe "initialization" do
    it "creates empty rule set with default error handlers" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      rule_set.rules.should be_empty
      # Error handlers now include default handlers
      rule_set.error_handlers.size.should eq(5)
      rule_set.has_error_handler?(:unterminated_string).should be_true
      rule_set.has_error_handler?(:unterminated_comment).should be_true
      rule_set.has_error_handler?(:invalid_escape).should be_true
      rule_set.has_error_handler?(:invalid_number).should be_true
      rule_set.has_error_handler?(:invalid_character).should be_true
    end
  end

  describe "add_rule method" do
    it "adds single rule" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      rule = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/)
      
      rule_set.add_rule(rule)
      
      rule_set.rules.size.should eq(1)
      rule_set.rules[0].should eq(rule)
    end

    it "sorts rules by priority (highest first)" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      low_priority = Hecate::Lex::Rule.new(RuleTestTokenKind::Identifier, /\w+/, priority: 1)
      high_priority = Hecate::Lex::Rule.new(RuleTestTokenKind::Keyword, /if/, priority: 10)
      medium_priority = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/, priority: 5)
      
      # Add in random order
      rule_set.add_rule(low_priority)
      rule_set.add_rule(high_priority)  
      rule_set.add_rule(medium_priority)
      
      # Should be sorted by priority (highest first)
      rule_set.rules[0].should eq(high_priority)
      rule_set.rules[1].should eq(medium_priority)
      rule_set.rules[2].should eq(low_priority)
    end

    it "handles equal priorities" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      rule1 = Hecate::Lex::Rule.new(RuleTestTokenKind::Keyword, /if/, priority: 5)
      rule2 = Hecate::Lex::Rule.new(RuleTestTokenKind::Keyword, /else/, priority: 5)
      
      rule_set.add_rule(rule1)
      rule_set.add_rule(rule2)
      
      rule_set.rules.size.should eq(2)
      # Both should have same priority
      rule_set.rules[0].priority.should eq(5)
      rule_set.rules[1].priority.should eq(5)
    end

    it "re-sorts after each addition" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      rule1 = Hecate::Lex::Rule.new(RuleTestTokenKind::Integer, /\d+/, priority: 1)
      rule2 = Hecate::Lex::Rule.new(RuleTestTokenKind::Keyword, /if/, priority: 10)
      
      rule_set.add_rule(rule1)
      rule_set.rules[0].should eq(rule1)
      
      rule_set.add_rule(rule2)
      rule_set.rules[0].should eq(rule2) # Higher priority now first
      rule_set.rules[1].should eq(rule1)
    end
  end

  describe "error handler management" do
    it "registers error handler with LexErrorHandler object" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      handler = Hecate::Lex::LexErrorHandler.new("test error", "here's some help")
      
      rule_set.register_error_handler(:test_error, handler)
      
      # Default handlers + 1 custom handler
      rule_set.error_handlers.size.should eq(6)
      rule_set.error_handlers[:test_error].should eq(handler)
    end

    it "registers error handler with inline message and help" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      rule_set.register_error_handler(:test_error, "block error", "here's some help")
      
      # Default handlers + 1 custom handler
      rule_set.error_handlers.size.should eq(6)
      rule_set.has_error_handler?(:test_error).should be_true
    end

    it "retrieves registered error handler" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      handler = Hecate::Lex::LexErrorHandler.new("test error", "here's some help")
      
      rule_set.register_error_handler(:test_error, handler)
      retrieved = rule_set.get_error_handler(:test_error)
      
      retrieved.should eq(handler)
    end

    it "returns nil for missing error handler" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      result = rule_set.get_error_handler(:missing)
      result.should be_nil
    end

    it "checks for error handler existence" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      rule_set.has_error_handler?(:missing).should be_false
      
      rule_set.register_error_handler(:exists, "exists error", "help text")
      
      rule_set.has_error_handler?(:exists).should be_true
      rule_set.has_error_handler?(:missing).should be_false
    end

    it "can register multiple error handlers" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      rule_set.register_error_handler(:error1, "error 1", "help for error 1")
      
      rule_set.register_error_handler(:error2, "error 2", "help for error 2")
      
      # Default handlers + 2 custom handlers
      rule_set.error_handlers.size.should eq(7)
      rule_set.has_error_handler?(:error1).should be_true
      rule_set.has_error_handler?(:error2).should be_true
    end
  end

  describe "integration with rules" do
    it "allows rules to reference error handlers" do
      rule_set = Hecate::Lex::RuleSet(RuleTestTokenKind).new
      
      # Register error handler
      rule_set.register_error_handler(:string_error, "unterminated string", "starts here")
      
      # Create rule with error handler reference
      rule = Hecate::Lex::Rule.new(
        RuleTestTokenKind::String,
        /"[^"]*"/,
        error_handler: :string_error
      )
      
      rule_set.add_rule(rule)
      
      # Verify rule has error handler reference
      rule_set.rules[0].error_handler.should eq(:string_error)
      
      # Verify error handler can be retrieved
      handler = rule_set.get_error_handler(:string_error)
      handler.should_not be_nil
    end
  end
end