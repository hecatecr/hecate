require "../../spec_helper"
require "hecate-core/test_utils"

# Token type for error handling tests
enum ErrorTestToken
  EOF
  String
  Comment
  Number
  Identifier
  Error # Special token type for error patterns
end

describe "Scanner error handling" do
  it "applies error handlers for error patterns" do
    # Create source
    source_map = Hecate::Core::SourceMap.new
    source_id = source_map.add_file("test.lang", "\"hello world") # Unterminated string

    # Create rules with error patterns
    rule_set = Hecate::Lex::RuleSet(ErrorTestToken).new

    # Normal string rule
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::String,
      /"[^"]*"/,
      priority: 10
    ))

    # Error pattern for unterminated string
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Error,
      /"[^"]*$/, # String that extends to end of input
      priority: 5,
      error_handler: :unterminated_string
    ))

    # Scan
    scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
    tokens, diagnostics = scanner.scan_all

    # Should have only EOF token (error pattern doesn't create token)
    tokens.size.should eq(1)
    tokens[0].kind.should eq(ErrorTestToken::EOF)

    # Should have one diagnostic
    diagnostics.size.should eq(1)
    diag = diagnostics[0]
    diag.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
    diag.message.should eq("unterminated string literal")
    diag.help.should eq("strings must be closed with a matching quote")
  end

  it "handles multiple error patterns" do
    # Create source with multiple errors
    source_map = Hecate::Core::SourceMap.new
    source_id = source_map.add_file("test.lang", "\"hello /* comment")

    # Create rules
    rule_set = Hecate::Lex::RuleSet(ErrorTestToken).new

    # Error pattern for unterminated string
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Error,
      /"[^"]*$/,
      priority: 10,
      error_handler: :unterminated_string
    ))

    # Error pattern for unterminated comment
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Error,
      %r{/\*[^*]*$},
      priority: 10,
      error_handler: :unterminated_comment
    ))

    # Scan
    scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
    tokens, diagnostics = scanner.scan_all

    # Should have diagnostics for the error that matched (longest match wins)
    diagnostics.should_not be_empty

    # The unterminated string pattern should win (matches more of the input)
    diagnostics[0].message.should eq("unterminated string literal")
  end

  it "continues scanning after error patterns" do
    # Create source
    source_map = Hecate::Core::SourceMap.new
    source_id = source_map.add_file("test.lang", "\"hello world 123abc") # Unterminated string followed by invalid number

    # Create rules
    rule_set = Hecate::Lex::RuleSet(ErrorTestToken).new

    # Whitespace rule (to skip spaces)
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Identifier, # Using identifier as placeholder
      /\s+/,
      skip: true,
      priority: 1
    ))

    # Valid number rule
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Number,
      /\d+/,
      priority: 10
    ))

    # Valid identifier rule
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Identifier,
      /[a-zA-Z]\w*/,
      priority: 5
    ))

    # Error pattern for unterminated strings
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Error,
      /"[^"]*$/, # String that goes to end of input
      priority: 20,
      error_handler: :unterminated_string
    ))

    # Error pattern for invalid numbers
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Error,
      /\d+[a-zA-Z]\w*/, # Number followed by letters
      priority: 15,
      error_handler: :invalid_number
    ))

    # Scan
    scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
    tokens, diagnostics = scanner.scan_all

    # Should have only EOF token (both patterns are errors)
    tokens.size.should eq(1)
    tokens[0].kind.should eq(ErrorTestToken::EOF)

    # Should have at least one diagnostic (unterminated string consumes rest of input)
    diagnostics.size.should be >= 1
    diagnostics[0].message.should eq("unterminated string literal")
  end

  it "uses custom error handlers" do
    # Create source
    source_map = Hecate::Core::SourceMap.new
    source_id = source_map.add_file("test.lang", "123abc") # Invalid number

    # Create rules
    rule_set = Hecate::Lex::RuleSet(ErrorTestToken).new

    # Register custom error handler
    rule_set.register_error_handler(:bad_number, "malformed numeric literal", "numbers cannot contain letters")

    # Valid number rule
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Number,
      /\d+/,
      priority: 10
    ))

    # Error pattern for numbers followed by letters
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Error,
      /\d+[a-zA-Z]+/,
      priority: 15,
      error_handler: :bad_number
    ))

    # Scan
    scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
    tokens, diagnostics = scanner.scan_all

    # Should have EOF token only
    tokens.size.should eq(1)
    tokens[0].kind.should eq(ErrorTestToken::EOF)

    # Should have custom diagnostic
    diagnostics.size.should eq(1)
    diagnostics[0].message.should eq("malformed numeric literal")
    diagnostics[0].help.should eq("numbers cannot contain letters")
  end

  it "handles missing error handlers gracefully" do
    # Create source
    source_map = Hecate::Core::SourceMap.new
    source_id = source_map.add_file("test.lang", "###")

    # Create rules
    rule_set = Hecate::Lex::RuleSet(ErrorTestToken).new

    # Error pattern with non-existent handler
    rule_set.add_rule(Hecate::Lex::Rule.new(
      ErrorTestToken::Error,
      /#+/,
      error_handler: :nonexistent_handler
    ))

    # Scan - should not crash
    scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
    tokens, diagnostics = scanner.scan_all

    # Should have EOF token
    tokens.size.should eq(1)
    tokens[0].kind.should eq(ErrorTestToken::EOF)

    # Should have no diagnostics (handler not found)
    diagnostics.size.should eq(0)
  end
end
