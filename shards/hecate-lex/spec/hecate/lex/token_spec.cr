require "../../spec_helper"

# Example token kind enum for testing
enum TestTokenKind
  Identifier
  Integer
  Float
  Plus
  Minus
  EOF
end

# Different enum for testing generics
enum AnotherTokenKind
  KeywordIf
  KeywordElse
  Symbol
end

describe Hecate::Lex::Token do
  describe "initialization" do
    it "creates a token with kind and span" do
      span = span(10, 5)
      token = Hecate::Lex::Token.new(TestTokenKind::Integer, span)

      token.kind.should eq(TestTokenKind::Integer)
      token.span.should eq(span)
      token.value.should be_nil
    end

    it "creates a token with kind, span, and value" do
      span = span(10, 5)
      token = Hecate::Lex::Token.new(TestTokenKind::Integer, span, "42")

      token.kind.should eq(TestTokenKind::Integer)
      token.span.should eq(span)
      token.value.should eq("42")
    end
  end

  describe "lexeme retrieval" do
    it "extracts lexeme from source map" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello world")
      source = source_map.get(source_id).not_nil!

      # Token for "hello" (bytes 0-5)
      token_span = Hecate::Core::Span.new(source_id, 0, 5)
      token = Hecate::Lex::Token.new(TestTokenKind::Identifier, token_span)

      token.lexeme(source_map).should eq("hello")
    end

    it "extracts lexeme from middle of source" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello world")
      source = source_map.get(source_id).not_nil!

      # Token for "world" (bytes 6-11)
      token_span = Hecate::Core::Span.new(source_id, 6, 11)
      token = Hecate::Lex::Token.new(TestTokenKind::Identifier, token_span)

      token.lexeme(source_map).should eq("world")
    end

    it "handles UTF-8 characters correctly" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "café")
      token_span = Hecate::Core::Span.new(source_id, 0, 5)
      token = Hecate::Lex::Token.new(TestTokenKind::Identifier, token_span)
      token.lexeme(source_map).should eq("café")
    end

    it "falls back to stored value when source is missing" do
      source_map = Hecate::Core::SourceMap.new
      # Use invalid source_id
      token_span = Hecate::Core::Span.new(999_u32, 0, 5)
      token = Hecate::Lex::Token.new(TestTokenKind::Integer, token_span, "42")

      token.lexeme(source_map).should eq("42")
    end

    it "falls back to <unknown> when source is missing and no value" do
      source_map = Hecate::Core::SourceMap.new
      # Use invalid source_id
      token_span = Hecate::Core::Span.new(999_u32, 0, 5)
      token = Hecate::Lex::Token.new(TestTokenKind::Integer, token_span)

      token.lexeme(source_map).should eq("<unknown>")
    end

    it "handles empty spans correctly" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello")

      # Empty span
      token_span = Hecate::Core::Span.new(source_id, 2, 2)
      token = Hecate::Lex::Token.new(TestTokenKind::EOF, token_span)

      token.lexeme(source_map).should eq("")
    end
  end

  describe "equality comparison" do
    it "compares tokens with same kind and span as equal" do
      span = span(0, 5)
      token1 = Hecate::Lex::Token.new(TestTokenKind::Integer, span)
      token2 = Hecate::Lex::Token.new(TestTokenKind::Integer, span)

      (token1 == token2).should be_true
    end

    it "compares tokens with different kinds as not equal" do
      span = span(0, 5)
      token1 = Hecate::Lex::Token.new(TestTokenKind::Integer, span)
      token2 = Hecate::Lex::Token.new(TestTokenKind::Float, span)

      (token1 == token2).should be_false
    end

    it "compares tokens with different spans as not equal" do
      span1 = span(0, 5)
      span2 = span(5, 3)
      token1 = Hecate::Lex::Token.new(TestTokenKind::Integer, span1)
      token2 = Hecate::Lex::Token.new(TestTokenKind::Integer, span2)

      (token1 == token2).should be_false
    end

    it "ignores value field in equality comparison" do
      span = span(0, 5)
      token1 = Hecate::Lex::Token.new(TestTokenKind::Integer, span, "42")
      token2 = Hecate::Lex::Token.new(TestTokenKind::Integer, span, "different")
      token3 = Hecate::Lex::Token.new(TestTokenKind::Integer, span)

      (token1 == token2).should be_true
      (token1 == token3).should be_true
      (token2 == token3).should be_true
    end
  end

  describe "generic type behavior" do
    it "works with different token kind enums" do
      span = span(0, 2)
      token = Hecate::Lex::Token.new(AnotherTokenKind::KeywordIf, span)

      token.kind.should eq(AnotherTokenKind::KeywordIf)
      token.span.should eq(span)
    end

    it "maintains type safety across different enums" do
      span1 = span(0, 2)
      span2 = span(0, 2)

      token1 = Hecate::Lex::Token.new(TestTokenKind::Integer, span1)
      token2 = Hecate::Lex::Token.new(AnotherTokenKind::KeywordIf, span2)

      # These should be different types and not comparable
      # token1 == token2 would be a compile error
      token1.kind.should be_a(TestTokenKind)
      token2.kind.should be_a(AnotherTokenKind)
    end
  end

  describe "edge cases" do
    it "handles very large spans" do
      source_map = Hecate::Core::SourceMap.new
      large_content = "x" * 100000
      source_id = source_map.add_file("large.txt", large_content)

      # Token for the entire large content
      token_span = Hecate::Core::Span.new(source_id, 0, 100000)
      token = Hecate::Lex::Token.new(TestTokenKind::Identifier, token_span)

      lexeme = token.lexeme(source_map)
      lexeme.size.should eq(100000)
      lexeme.should eq(large_content)
    end

    it "handles span at end of source" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "hello")

      # Token at the very end (empty)
      token_span = Hecate::Core::Span.new(source_id, 5, 5)
      token = Hecate::Lex::Token.new(TestTokenKind::EOF, token_span)

      token.lexeme(source_map).should eq("")
    end

    it "handles spans with special characters" do
      source_map = Hecate::Core::SourceMap.new
      special_content = "line1\n\tline2\r\nline3"
      source_id = source_map.add_file("special.txt", special_content)

      # Token for "\n\t" (bytes 5-7)
      token_span = Hecate::Core::Span.new(source_id, 5, 7)
      token = Hecate::Lex::Token.new(TestTokenKind::Identifier, token_span)

      token.lexeme(source_map).should eq("\n\t")
    end
  end

  describe "performance characteristics" do
    it "lexeme method is lazy and doesn't cache" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", "original")

      token_span = Hecate::Core::Span.new(source_id, 0, 8)
      token = Hecate::Lex::Token.new(TestTokenKind::Identifier, token_span)

      # First call
      token.lexeme(source_map).should eq("original")

      # Simulate source change (in practice, SourceMap is immutable,
      # but this tests that lexeme doesn't cache internally)
      # We can't actually change the source in SourceMap, so this
      # test verifies that multiple calls work consistently
      token.lexeme(source_map).should eq("original")
    end
  end
end
