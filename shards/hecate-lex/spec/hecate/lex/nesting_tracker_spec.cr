require "../../spec_helper"

describe Hecate::Lex::NestingTracker do
  describe "#process and #balanced?" do
    it "tracks balanced brackets correctly" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET],
        close_tokens: [:RBRACE, :RBRACKET]
      )
      
      # Process: { [ ] }
      tracker.process(:LBRACE).should eq(0)
      tracker.level.should eq(1)
      
      tracker.process(:LBRACKET).should eq(1)
      tracker.level.should eq(2)
      
      tracker.process(:RBRACKET).should eq(1)
      tracker.level.should eq(1)
      
      tracker.process(:RBRACE).should eq(0)
      tracker.level.should eq(0)
      
      tracker.balanced?.should be_true
    end
    
    it "detects unbalanced brackets with missing closing" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # Process: { { }
      tracker.process(:LBRACE)
      tracker.process(:LBRACE)
      tracker.process(:RBRACE)
      
      tracker.balanced?.should be_false
      tracker.level.should eq(1)
      tracker.unclosed_tokens.should eq([:LBRACE])
    end
    
    it "detects unbalanced brackets with missing opening" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # Process: { } }
      tracker.process(:LBRACE)
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)  # Extra closing brace
      
      tracker.balanced?.should be_false
      tracker.validation_error.should_not be_nil
    end
    
    it "handles deeply nested structures" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # Process: { { { } } }
      tracker.process(:LBRACE).should eq(0)
      tracker.process(:LBRACE).should eq(1)
      tracker.process(:LBRACE).should eq(2)
      tracker.process(:RBRACE).should eq(2)
      tracker.process(:RBRACE).should eq(1)
      tracker.process(:RBRACE).should eq(0)
      
      tracker.balanced?.should be_true
    end
    
    it "detects mismatched bracket types when pairs are defined" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET],
        close_tokens: [:RBRACE, :RBRACKET],
        pairs: {
          :RBRACE => :LBRACE,
          :RBRACKET => :LBRACKET
        }
      )
      
      # Process: { [ } ] - mismatched
      tracker.process(:LBRACE)
      tracker.process(:LBRACKET)
      tracker.process(:RBRACE)  # Should close LBRACE, but LBRACKET is on top
      tracker.process(:RBRACKET)
      
      # The current implementation might not handle this perfectly
      # but at least the stack should not be empty if there's a mismatch
      tracker.balanced?.should be_false
    end
    
    it "handles empty input" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      tracker.balanced?.should be_true
      tracker.level.should eq(0)
    end
    
    it "resets state correctly" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      tracker.process(:LBRACE)
      tracker.process(:LBRACE)
      
      tracker.level.should eq(2)
      tracker.balanced?.should be_false
      
      tracker.reset
      
      tracker.level.should eq(0)
      tracker.balanced?.should be_true
      tracker.stack.should be_empty
    end
  end
  
  describe "#validation_error" do
    it "returns nil when balanced" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      tracker.process(:LBRACE)
      tracker.process(:RBRACE)
      
      tracker.validation_error.should be_nil
    end
    
    it "reports unclosed tokens" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET],
        close_tokens: [:RBRACE, :RBRACKET]
      )
      
      tracker.process(:LBRACE)
      tracker.process(:LBRACKET)
      
      error = tracker.validation_error
      error.should_not be_nil
      error.not_nil!.should contain("Unclosed tokens")
      error.not_nil!.should contain("LBRACE")
      error.not_nil!.should contain("LBRACKET")
    end
    
    it "reports too many closing tokens" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)
      
      error = tracker.validation_error
      error.should_not be_nil
      # This test will likely fail with current implementation
      # because level can't go negative
    end
  end
  
  describe ".bracket_tracker" do
    it "creates a tracker with common bracket pairs" do
      tracker = Hecate::Lex.bracket_tracker(
        brace_open: :LBRACE,
        brace_close: :RBRACE,
        bracket_open: :LBRACKET,
        bracket_close: :RBRACKET,
        paren_open: :LPAREN,
        paren_close: :RPAREN
      )
      
      tracker.open_tokens.should contain(:LBRACE)
      tracker.open_tokens.should contain(:LBRACKET)
      tracker.open_tokens.should contain(:LPAREN)
      
      tracker.close_tokens.should contain(:RBRACE)
      tracker.close_tokens.should contain(:RBRACKET)
      tracker.close_tokens.should contain(:RPAREN)
      
      pairs = tracker.pairs
      pairs.should_not be_nil
      pairs.not_nil![:RBRACE].should eq(:LBRACE)
      pairs.not_nil![:RBRACKET].should eq(:LBRACKET)
      pairs.not_nil![:RPAREN].should eq(:LPAREN)
    end
  end
end