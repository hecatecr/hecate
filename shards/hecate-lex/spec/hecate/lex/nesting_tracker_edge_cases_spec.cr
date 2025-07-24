require "../../spec_helper"

describe "Hecate::Lex::NestingTracker edge cases" do
  describe "mismatched bracket types" do
    it "detects simple mismatched types { ]" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET],
        close_tokens: [:RBRACE, :RBRACKET],
        pairs: {
          :RBRACE => :LBRACE,
          :RBRACKET => :LBRACKET
        }
      )
      
      tracker.process(:LBRACE)
      tracker.process(:RBRACKET)  # Wrong closing type
      
      tracker.balanced?.should be_false
      # Stack should still have LBRACE since RBRACKET doesn't match
      tracker.stack.should eq([:LBRACE])
      tracker.extra_closing_tokens.should eq(1)
    end
    
    it "detects complex interleaved mismatches { [ } ]" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET],
        close_tokens: [:RBRACE, :RBRACKET],
        pairs: {
          :RBRACE => :LBRACE,
          :RBRACKET => :LBRACKET
        }
      )
      
      # { [ } ] - Classic interleaved mismatch
      tracker.process(:LBRACE)   # Stack: [LBRACE]
      tracker.process(:LBRACKET) # Stack: [LBRACE, LBRACKET]
      tracker.process(:RBRACE)   # Expects LBRACKET but found RBRACE
      tracker.process(:RBRACKET) # Matches LBRACKET
      
      tracker.balanced?.should be_false
      tracker.validation_error.should_not be_nil
    end
    
    it "handles multiple types with correct pairing" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET, :LPAREN],
        close_tokens: [:RBRACE, :RBRACKET, :RPAREN],
        pairs: {
          :RBRACE => :LBRACE,
          :RBRACKET => :LBRACKET,
          :RPAREN => :LPAREN
        }
      )
      
      # { [ ( ) ] }
      tracker.process(:LBRACE)
      tracker.process(:LBRACKET)
      tracker.process(:LPAREN)
      tracker.process(:RPAREN)
      tracker.process(:RBRACKET)
      tracker.process(:RBRACE)
      
      tracker.balanced?.should be_true
    end
  end
  
  describe "multiple errors in sequence" do
    it "tracks multiple extra closing tokens" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # { } } } - multiple extra closes
      tracker.process(:LBRACE)
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)  # Extra 1
      tracker.process(:RBRACE)  # Extra 2
      
      tracker.balanced?.should be_false
      tracker.extra_closing_tokens.should eq(2)
      tracker.validation_error.should match(/2 extra/)
    end
    
    it "handles alternating opens and extra closes" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # } { } } { - Complex pattern
      tracker.process(:RBRACE)  # Extra close at start
      tracker.process(:LBRACE)
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)  # Extra close
      tracker.process(:LBRACE)  # Unclosed at end
      
      tracker.balanced?.should be_false
      tracker.extra_closing_tokens.should eq(2)
      tracker.stack.should eq([:LBRACE])
    end
  end
  
  describe "error recovery behavior" do
    it "continues tracking after encountering errors" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # } { { } } - Error at start, then valid nested structure
      tracker.process(:RBRACE)  # Error: extra close
      
      # Should still track the valid structure that follows
      tracker.process(:LBRACE)
      tracker.process(:LBRACE)
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)
      
      # Still unbalanced due to initial error
      tracker.balanced?.should be_false
      tracker.extra_closing_tokens.should eq(1)
      tracker.stack.should be_empty
    end
    
    it "maintains correct level after errors" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # Track levels through error scenarios
      tracker.level.should eq(0)
      
      tracker.process(:RBRACE)  # Extra close
      tracker.level.should eq(0)  # Level stays at 0
      
      tracker.process(:LBRACE)
      tracker.level.should eq(1)
      
      tracker.process(:RBRACE)
      tracker.level.should eq(0)
    end
  end
  
  describe "deeply nested structures" do
    it "handles very deep nesting correctly" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # Create deep nesting
      depth = 100
      depth.times { tracker.process(:LBRACE) }
      
      tracker.level.should eq(depth)
      tracker.stack.size.should eq(depth)
      
      # Close all but one
      (depth - 1).times { tracker.process(:RBRACE) }
      
      tracker.level.should eq(1)
      tracker.balanced?.should be_false
      tracker.stack.size.should eq(1)
    end
    
    it "handles deep nesting with errors in the middle" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET],
        close_tokens: [:RBRACE, :RBRACKET],
        pairs: {
          :RBRACE => :LBRACE,
          :RBRACKET => :LBRACKET
        }
      )
      
      # { { { [ [ } ] ] } } - Mismatch in the middle
      tracker.process(:LBRACE)
      tracker.process(:LBRACE)
      tracker.process(:LBRACE)
      tracker.process(:LBRACKET)
      tracker.process(:LBRACKET)
      tracker.process(:RBRACE)   # Wrong type, expects RBRACKET
      tracker.process(:RBRACKET)
      tracker.process(:RBRACKET)
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)
      
      tracker.balanced?.should be_false
    end
  end
  
  describe "empty input edge cases" do
    it "handles only closing tokens" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)
      tracker.process(:RBRACE)
      
      tracker.balanced?.should be_false
      tracker.extra_closing_tokens.should eq(3)
      tracker.level.should eq(0)
      tracker.stack.should be_empty
    end
    
    it "handles single token sequences" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      # Just one open
      tracker.process(:LBRACE)
      tracker.balanced?.should be_false
      tracker.validation_error.should match(/Unclosed/)
      
      tracker.reset
      
      # Just one close
      tracker.process(:RBRACE)
      tracker.balanced?.should be_false
      tracker.validation_error.should match(/Too many closing/)
    end
  end
  
  describe "token types not in open/close sets" do
    it "ignores non-bracket tokens" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE],
        close_tokens: [:RBRACE]
      )
      
      tracker.process(:LBRACE)
      tracker.process(:STRING)    # Not a bracket
      tracker.process(:NUMBER)    # Not a bracket
      tracker.process(:COLON)     # Not a bracket
      tracker.process(:RBRACE)
      
      tracker.balanced?.should be_true
      tracker.level.should eq(0)
    end
  end
  
  describe "state inspection methods" do
    it "provides detailed state information" do
      tracker = Hecate::Lex::NestingTracker.new(
        open_tokens: [:LBRACE, :LBRACKET],
        close_tokens: [:RBRACE, :RBRACKET],
        pairs: {
          :RBRACE => :LBRACE,
          :RBRACKET => :LBRACKET
        }
      )
      
      tracker.process(:LBRACE)
      tracker.process(:LBRACKET)
      tracker.process(:LBRACE)
      
      # Check we can inspect the state
      tracker.level.should eq(3)
      tracker.stack.should eq([:LBRACE, :LBRACKET, :LBRACE])
      tracker.unclosed_tokens.should eq([:LBRACE, :LBRACKET, :LBRACE])
      tracker.extra_closing_tokens.should eq(0)
      
      # Process some closes
      tracker.process(:RBRACE)     # Closes the last LBRACE
      tracker.level.should eq(2)
      tracker.stack.should eq([:LBRACE, :LBRACKET])
      
      tracker.process(:RBRACE)      # This is a mismatch - expects RBRACKET
      tracker.level.should eq(2)   # Level doesn't change on mismatch
      tracker.extra_closing_tokens.should eq(1)
    end
  end
end