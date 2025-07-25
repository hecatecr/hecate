require "../../spec_helper"
require "hecate-core/test_utils"

# Dummy token type for testing
enum TestToken2
  String
  Comment
end

describe Hecate::Lex::Rule do
  describe "error handler reference" do
    it "creates rule without error handler" do
      rule = Hecate::Lex::Rule.new(TestToken2::String, /"[^"]*"/)
      rule.error_handler.should be_nil
    end

    it "creates rule with error handler reference" do
      rule = Hecate::Lex::Rule.new(
        TestToken2::String,
        /"[^"]*/, # Unterminated string pattern
        error_handler: :unterminated_string
      )
      rule.error_handler.should eq(:unterminated_string)
    end

    it "preserves error handler through rule properties" do
      rule = Hecate::Lex::Rule.new(
        TestToken2::Comment,
        %r{/\*[^*]*}, # Unterminated comment pattern
        skip: true,
        priority: 10,
        error_handler: :unterminated_comment
      )

      rule.kind.should eq(TestToken2::Comment)
      rule.skip.should be_true
      rule.priority.should eq(10)
      rule.error_handler.should eq(:unterminated_comment)
    end
  end
end
