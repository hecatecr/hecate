require "../../spec_helper"
require "hecate-core/test_utils"

# Define a simple token enum for testing
enum StreamTestTokenKind
  Identifier
  Number
  Plus
  Minus
  EOF
end

# Helper to create a token with minimal span
def make_stream_token(kind : StreamTestTokenKind, start_pos : Int32, end_pos : Int32)
  span = Hecate::Core::Span.new(0_u32, start_pos, end_pos)
  Hecate::Lex::Token.new(kind, span)
end

# Helper to create a token array for testing
def make_stream_tokens
  [
    make_stream_token(StreamTestTokenKind::Identifier, 0, 3),   # "foo"
    make_stream_token(StreamTestTokenKind::Plus, 4, 5),         # "+"
    make_stream_token(StreamTestTokenKind::Number, 6, 8),       # "42"
    make_stream_token(StreamTestTokenKind::Minus, 9, 10),       # "-"
    make_stream_token(StreamTestTokenKind::Identifier, 11, 14), # "bar"
    make_stream_token(StreamTestTokenKind::EOF, 14, 14),        # EOF
  ]
end

describe Hecate::Lex::TokenStream do
  describe "#peek" do
    it "returns the current token without advancing" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      token1 = stream.peek
      token2 = stream.peek

      token1.should eq(token2)
      token1.kind.should eq(StreamTestTokenKind::Identifier)
      stream.position.should eq(0)
    end

    it "raises when peeking past EOF" do
      tokens = [make_stream_token(StreamTestTokenKind::EOF, 0, 0)]
      stream = Hecate::Lex::TokenStream.new(tokens)

      stream.advance # Consume EOF

      expect_raises(Exception, "Unexpected end of token stream") do
        stream.peek
      end
    end
  end

  describe "#peek(n)" do
    it "looks ahead n positions" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      stream.peek(0).not_nil!.kind.should eq(StreamTestTokenKind::Identifier)
      stream.peek(1).not_nil!.kind.should eq(StreamTestTokenKind::Plus)
      stream.peek(2).not_nil!.kind.should eq(StreamTestTokenKind::Number)
      stream.peek(5).not_nil!.kind.should eq(StreamTestTokenKind::EOF)
      stream.position.should eq(0) # Position unchanged
    end

    it "returns nil when looking beyond EOF" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      stream.peek(6).should be_nil
      stream.peek(100).should be_nil
    end

    it "works correctly with pushed-back tokens" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      # Advance and push back
      first = stream.advance
      second = stream.advance
      stream.push(second)
      stream.push(first)

      stream.peek(0).not_nil!.kind.should eq(StreamTestTokenKind::Identifier)
      stream.peek(1).not_nil!.kind.should eq(StreamTestTokenKind::Plus)
      stream.peek(2).not_nil!.kind.should eq(StreamTestTokenKind::Number)
    end
  end

  describe "#advance" do
    it "consumes and returns the current token" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      token = stream.advance
      token.kind.should eq(StreamTestTokenKind::Identifier)
      stream.position.should eq(1)

      next_token = stream.peek
      next_token.kind.should eq(StreamTestTokenKind::Plus)
    end

    it "raises when advancing past EOF" do
      tokens = [make_stream_token(StreamTestTokenKind::EOF, 0, 0)]
      stream = Hecate::Lex::TokenStream.new(tokens)

      stream.advance # Consume EOF

      expect_raises(Exception, "Unexpected end of token stream") do
        stream.advance
      end
    end
  end

  describe "#push" do
    it "pushes tokens back onto the stream" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      # Advance twice
      first = stream.advance
      second = stream.advance

      # Push back in reverse order
      stream.push(second)
      stream.push(first)

      # Should get them back in LIFO order
      stream.advance.should eq(first)
      stream.advance.should eq(second)
    end

    it "allows multiple push operations" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      tokens = [] of Hecate::Lex::Token(StreamTestTokenKind)
      3.times { tokens << stream.advance }

      # Push all back
      tokens.reverse.each { |t| stream.push(t) }

      # Should get them back in original order
      3.times do |i|
        stream.advance.should eq(tokens[i])
      end
    end
  end

  describe "#eof?" do
    it "returns false when tokens remain" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)
      stream.eof?.should be_false
    end

    it "returns true when all tokens consumed" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      6.times { stream.advance }
      stream.eof?.should be_true
    end

    it "returns false when tokens are pushed back" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      # Consume all
      tokens = [] of Hecate::Lex::Token(StreamTestTokenKind)
      6.times { tokens << stream.advance }

      stream.eof?.should be_true

      # Push one back
      stream.push(tokens.last)
      stream.eof?.should be_false
    end
  end

  describe "#position" do
    it "tracks the position in the original array" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      stream.position.should eq(0)
      stream.advance
      stream.position.should eq(1)
      stream.advance
      stream.position.should eq(2)
    end

    it "is not affected by push operations" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      token = stream.advance
      stream.position.should eq(1)

      stream.push(token)
      stream.position.should eq(1) # Unchanged
    end
  end

  describe "#remaining" do
    it "counts remaining tokens including pushed back" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      stream.remaining.should eq(6)

      stream.advance
      stream.remaining.should eq(5)

      # Push back
      stream.push(make_stream_token(StreamTestTokenKind::Plus, 0, 0))
      stream.remaining.should eq(6)
    end
  end

  describe "#consume_while" do
    it "consumes tokens matching the condition" do
      tokens = [
        make_stream_token(StreamTestTokenKind::Identifier, 0, 3),
        make_stream_token(StreamTestTokenKind::Identifier, 4, 7),
        make_stream_token(StreamTestTokenKind::Plus, 8, 9),
        make_stream_token(StreamTestTokenKind::Number, 10, 12),
      ]
      stream = Hecate::Lex::TokenStream.new(tokens)

      identifiers = stream.consume_while { |t| t.kind == StreamTestTokenKind::Identifier }

      identifiers.size.should eq(2)
      identifiers.all? { |t| t.kind == StreamTestTokenKind::Identifier }.should be_true
      stream.peek.kind.should eq(StreamTestTokenKind::Plus)
    end

    it "returns empty array when no tokens match" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      numbers = stream.consume_while { |t| t.kind == StreamTestTokenKind::Number }

      numbers.should be_empty
      stream.position.should eq(0)
    end
  end

  describe "#expect" do
    it "consumes token when kind matches" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      token = stream.expect(StreamTestTokenKind::Identifier)
      token.kind.should eq(StreamTestTokenKind::Identifier)
      stream.position.should eq(1)
    end

    it "raises when kind doesn't match" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      expect_raises(Exception, /Expected Number but found Identifier/) do
        stream.expect(StreamTestTokenKind::Number)
      end
    end

    it "raises when at EOF" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)
      6.times { stream.advance }

      expect_raises(Exception, /Expected Plus but found EOF/) do
        stream.expect(StreamTestTokenKind::Plus)
      end
    end
  end

  describe "#try_match" do
    it "consumes and returns token when kind matches" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      token = stream.try_match(StreamTestTokenKind::Identifier)
      token.should_not be_nil
      token.not_nil!.kind.should eq(StreamTestTokenKind::Identifier)
      stream.position.should eq(1)
    end

    it "returns nil when kind doesn't match" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)

      token = stream.try_match(StreamTestTokenKind::Number)
      token.should be_nil
      stream.position.should eq(0) # No advancement
    end

    it "returns nil at EOF" do
      stream = Hecate::Lex::TokenStream.new(make_stream_tokens)
      6.times { stream.advance }

      token = stream.try_match(StreamTestTokenKind::Plus)
      token.should be_nil
    end
  end
end
