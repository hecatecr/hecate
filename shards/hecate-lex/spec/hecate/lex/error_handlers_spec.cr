require "../../spec_helper"
require "hecate-core/test_utils"

describe Hecate::Lex::LexErrorHandler do
  it "initializes with message and optional help" do
    handler = Hecate::Lex::LexErrorHandler.new("test error")
    handler.message.should eq("test error")
    handler.help.should be_nil
    
    handler_with_help = Hecate::Lex::LexErrorHandler.new("test error", "helpful hint")
    handler_with_help.message.should eq("test error")
    handler_with_help.help.should eq("helpful hint")
  end
end

describe Hecate::Lex::CommonErrors do
  it "provides unterminated string error handler" do
    handler = Hecate::Lex::CommonErrors::UNTERMINATED_STRING
    handler.message.should eq("unterminated string literal")
    handler.help.should eq("strings must be closed with a matching quote")
  end
  
  it "provides unterminated comment error handler" do
    handler = Hecate::Lex::CommonErrors::UNTERMINATED_COMMENT
    handler.message.should eq("unterminated block comment")
    handler.help.should eq("block comments must be closed with */")
  end
  
  it "provides invalid escape error handler" do
    handler = Hecate::Lex::CommonErrors::INVALID_ESCAPE
    handler.message.should eq("invalid escape sequence")
    handler.help.should eq("valid escape sequences are: \\n \\r \\t \\\\ \\\"")
  end
  
  it "provides invalid number error handler" do
    handler = Hecate::Lex::CommonErrors::INVALID_NUMBER
    handler.message.should eq("invalid number literal")
    handler.help.should eq("numbers must be in a valid format (e.g., 123, 0x7F, 3.14)")
  end
  
  it "provides invalid character error handler" do
    handler = Hecate::Lex::CommonErrors::INVALID_CHARACTER
    handler.message.should eq("invalid character")
    handler.help.should eq("this character is not allowed in this context")
  end
end