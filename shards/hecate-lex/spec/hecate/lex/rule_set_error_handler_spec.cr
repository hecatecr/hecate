require "../../spec_helper"
require "hecate-core/test_utils"

# Dummy token type for testing
enum TestToken
  EOF
  String
  Number
  Identifier
end

describe Hecate::Lex::RuleSet do
  describe "error handler management" do
    it "initializes with default error handlers" do
      rule_set = Hecate::Lex::RuleSet(TestToken).new

      # Check that default handlers are registered
      rule_set.has_error_handler?(:unterminated_string).should be_true
      rule_set.has_error_handler?(:unterminated_comment).should be_true
      rule_set.has_error_handler?(:invalid_escape).should be_true
      rule_set.has_error_handler?(:invalid_number).should be_true
      rule_set.has_error_handler?(:invalid_character).should be_true
    end

    it "retrieves default error handlers" do
      rule_set = Hecate::Lex::RuleSet(TestToken).new

      handler = rule_set.get_error_handler(:unterminated_string)
      handler.should_not be_nil
      handler.not_nil!.message.should eq("unterminated string literal")
      handler.not_nil!.help.should eq("strings must be closed with a matching quote")
    end

    it "registers custom error handlers" do
      rule_set = Hecate::Lex::RuleSet(TestToken).new

      # Register with LexErrorHandler object
      custom_handler = Hecate::Lex::LexErrorHandler.new("custom error", "custom help")
      rule_set.register_error_handler(:custom_error, custom_handler)

      retrieved = rule_set.get_error_handler(:custom_error)
      retrieved.should_not be_nil
      retrieved.not_nil!.message.should eq("custom error")
      retrieved.not_nil!.help.should eq("custom help")
    end

    it "registers error handlers with inline values" do
      rule_set = Hecate::Lex::RuleSet(TestToken).new

      # Register with message and help
      rule_set.register_error_handler(:inline_error, "inline message", "inline help")

      handler = rule_set.get_error_handler(:inline_error)
      handler.should_not be_nil
      handler.not_nil!.message.should eq("inline message")
      handler.not_nil!.help.should eq("inline help")

      # Register with message only
      rule_set.register_error_handler(:no_help_error, "no help message")

      handler2 = rule_set.get_error_handler(:no_help_error)
      handler2.should_not be_nil
      handler2.not_nil!.message.should eq("no help message")
      handler2.not_nil!.help.should be_nil
    end

    it "returns nil for non-existent error handlers" do
      rule_set = Hecate::Lex::RuleSet(TestToken).new

      handler = rule_set.get_error_handler(:nonexistent)
      handler.should be_nil
    end

    it "checks for error handler existence" do
      rule_set = Hecate::Lex::RuleSet(TestToken).new

      rule_set.has_error_handler?(:unterminated_string).should be_true
      rule_set.has_error_handler?(:nonexistent).should be_false
    end
  end
end
