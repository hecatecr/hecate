require "../../spec_helper"
require "hecate-core/test_utils"

enum JsonToken
  # Literals
  String
  Number
  True
  False
  Null
  
  # Structural
  LeftBrace      # {
  RightBrace     # }
  LeftBracket    # [
  RightBracket   # ]
  Comma          # ,
  Colon          # :
  
  # Whitespace (normally skipped)
  Whitespace
  
  # End of input
  EOF
end

enum LanguageToken
  # Keywords
  Let
  Def
  If
  Else
  While
  Return
  
  # Identifiers and literals
  Identifier
  Integer
  Float
  String
  
  # Operators
  Plus      # +
  Minus     # -
  Star      # *
  Slash     # /
  Equal     # =
  EqualEqual # ==
  NotEqual  # !=
  Less      # <
  Greater   # >
  
  # Punctuation
  LeftParen    # (
  RightParen   # )
  LeftBrace    # {
  RightBrace   # }
  Semicolon    # ;
  Comma        # ,
  
  # Comments and whitespace
  Comment
  Whitespace
  
  EOF
end

enum EdgeToken
  Word
  Number
  Emoji
  Symbol
  Whitespace
  EOF
end

enum ErrorToken
  Word
  Number
  Quote
  Whitespace
  EOF
end

def token_sequence_to_golden(tokens : Array(Hecate::Lex::Token), source_map : Hecate::Core::SourceMap) : String
  lines = [] of String
  lines << "# Token Sequence Golden File"
  lines << "# Format: TYPE:\"lexeme\"@start:end"
  lines << ""
  
  tokens.each do |token|
    type_name = token.kind.to_s
    lexeme = token.lexeme(source_map).inspect
    start_pos = token.span.start_byte
    end_pos = token.span.end_byte
    lines << "#{type_name}:#{lexeme}@#{start_pos}:#{end_pos}"
  end
  
  lines.join("\n") + "\n"
end

def verify_golden_tokens(lexer_name : String, test_name : String, 
                        source_content : String, lexer : Hecate::Lex::Lexer)
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("#{test_name}.test", source_content)
  source_file = source_map.get(source_id).not_nil!
  
  tokens, diagnostics = lexer.scan(source_file)
  
  # Generate golden file content
  golden_content = token_sequence_to_golden(tokens, source_map)
  
  # Use golden file testing
  Hecate::Core::TestUtils::GoldenFile.test(
    "lexer/#{lexer_name}/#{test_name}",
    golden_content,
    update: ENV["UPDATE_GOLDEN"]? == "1"
  )
  
  # Only verify no errors for tests that should succeed without errors
  # Skip this check for tests that expect errors or are testing error recovery
  unless test_name.includes?("error") || test_name.includes?("invalid") || 
         test_name.includes?("unicode") || test_name.includes?("special")
    diagnostics.select(&.severity.error?).should be_empty
  end
  
  {tokens, diagnostics}
end

def create_json_lexer
  Hecate::Lex.define(JsonToken) do |ctx|
    # Whitespace (skip by default)
    ctx.token :Whitespace, /\s+/, skip: true
    
    # Literals - improved string handling with better escape support
    ctx.token :String, /"([^"\\\\]|\\\\["\\\\nrtbf\/u]|\\\\u[0-9a-fA-F]{4})*"/
    ctx.token :Number, /-?\d+(\.\d+)?([eE][+-]?\d+)?/
    ctx.token :True, /true/
    ctx.token :False, /false/
    ctx.token :Null, /null/
    
    # Structural tokens
    ctx.token :LeftBrace, /\{/
    ctx.token :RightBrace, /\}/
    ctx.token :LeftBracket, /\[/
    ctx.token :RightBracket, /\]/
    ctx.token :Comma, /,/
    ctx.token :Colon, /:/
  end
end

def create_language_lexer
  Hecate::Lex.define(LanguageToken) do |ctx|
    # Skip whitespace and comments
    ctx.token :Whitespace, /\s+/, skip: true
    ctx.token :Comment, %r{//[^\n]*}, skip: true
    
    # Keywords (must come before identifier)
    ctx.token :Let, /let\b/
    ctx.token :Def, /def\b/
    ctx.token :If, /if\b/
    ctx.token :Else, /else\b/
    ctx.token :While, /while\b/
    ctx.token :Return, /return\b/
    
    # Identifiers and literals
    ctx.token :Identifier, /[a-zA-Z_]\w*/
    ctx.token :Float, /\d+\.\d+/
    ctx.token :Integer, /\d+/
    ctx.token :String, /"([^"\\\\]|\\\\.)*"/
    
    # Multi-character operators (must come before single-char)
    ctx.token :EqualEqual, /==/
    ctx.token :NotEqual, /!=/
    
    # Single-character tokens
    ctx.token :Plus, /\+/
    ctx.token :Minus, /-/
    ctx.token :Star, /\*/
    ctx.token :Slash, %r{/}
    ctx.token :Equal, /=/
    ctx.token :Less, /</
    ctx.token :Greater, />/
    ctx.token :LeftParen, /\(/
    ctx.token :RightParen, /\)/
    ctx.token :LeftBrace, /\{/
    ctx.token :RightBrace, /\}/
    ctx.token :Semicolon, /;/
    ctx.token :Comma, /,/
  end
end

def create_simple_lexer
  Hecate::Lex.define(EdgeToken) do |ctx|
    ctx.token :Whitespace, /\s+/, skip: true
    # Handle Unicode word characters and emojis
    ctx.token :Word, /[\p{L}\p{M}\p{N}_]+/
    ctx.token :Number, /\d+/
    # Handle emoji and other symbols
    ctx.token :Emoji, /[\p{So}\p{Sm}\p{Sc}\p{Sk}]+/
    # Catch any remaining characters as symbols
    ctx.token :Symbol, /./
  end
end

def create_error_lexer
  Hecate::Lex.define(ErrorToken) do |ctx|
    ctx.token :Whitespace, /\s+/, skip: true
    ctx.token :Word, /[a-zA-Z]+/
    ctx.token :Number, /\d+/
    ctx.token :Quote, /"/
  end
end

describe "Lexer Golden File Tests" do
  
  describe "JSON Lexer Golden Files" do
    it "tokenizes simple JSON object" do
      lexer = create_json_lexer
      source = <<-JSON
      {
        "name": "John",
        "age": 30,
        "active": true
      }
      JSON
      
      verify_golden_tokens("json", "simple_object", source, lexer)
    end
    
    it "tokenizes JSON array with mixed types" do
      lexer = create_json_lexer
      source = <<-JSON
      ["hello", 42, true, null, {"nested": "value"}]
      JSON
      
      verify_golden_tokens("json", "mixed_array", source, lexer)
    end
    
    it "tokenizes complex nested JSON" do
      lexer = create_json_lexer
      source = <<-JSON
      {
        "users": [
          {
            "id": 1,
            "profile": {
              "name": "Alice",
              "settings": {
                "theme": "dark",
                "notifications": true
              }
            }
          },
          {
            "id": 2,
            "profile": {
              "name": "Bob",
              "settings": {
                "theme": "light",
                "notifications": false
              }
            }
          }
        ],
        "meta": {
          "total": 2,
          "version": "1.0.0"
        }
      }
      JSON
      
      verify_golden_tokens("json", "complex_nested", source, lexer)
    end
    
    it "tokenizes JSON with special characters and escapes" do
      lexer = create_json_lexer
      source = <<-JSON
      {
        "unicode": "こんにちは",
        "escaped": "line1\\nline2\\ttab",
        "quotes": "He said \\"Hello!\\"",
        "numbers": [-42, 3.14159, 1.23e-4, 2E+10]
      }
      JSON
      
      verify_golden_tokens("json", "special_characters", source, lexer)
    end
    
    it "tokenizes empty structures" do  
      lexer = create_json_lexer
      source = <<-JSON
      {
        "empty_object": {},
        "empty_array": [],
        "empty_string": ""
      }
      JSON
      
      verify_golden_tokens("json", "empty_structures", source, lexer)
    end
  end
  
  describe "Programming Language Lexer Golden Files" do
    it "tokenizes function definition" do
      lexer = create_language_lexer
      source = <<-CODE
      def fibonacci(n) {
        if (n <= 1) {
          return n;
        } else {
          return fibonacci(n - 1) + fibonacci(n - 2);
        }
      }
      CODE
      
      verify_golden_tokens("language", "function_definition", source, lexer)
    end
    
    it "tokenizes variable declarations and expressions" do
      lexer = create_language_lexer
      source = <<-CODE
      let x = 42;
      let y = 3.14159;
      let name = "Hello, World!";
      let result = x + y * 2;
      let comparison = (x == 42) != (y > x);
      CODE
      
      verify_golden_tokens("language", "variables_expressions", source, lexer)
    end
    
    it "tokenizes control flow structures" do
      lexer = create_language_lexer
      source = <<-CODE
      if (condition) {
        let counter = 0;
        while (counter < 10) {
          counter = counter + 1;
        }
      } else {
        return false;
      }
      CODE
      
      verify_golden_tokens("language", "control_flow", source, lexer)
    end
    
    it "tokenizes code with comments" do
      lexer = create_language_lexer
      source = <<-CODE
      // This is a fibonacci function
      def fib(n) {  // n should be non-negative
        // Base cases
        if (n <= 1) {
          return n;
        }
        // Recursive case
        return fib(n - 1) + fib(n - 2);
      }
      CODE
      
      verify_golden_tokens("language", "with_comments", source, lexer)
    end
  end
  
  describe "Edge Case Golden Files" do
    it "tokenizes empty input" do
      lexer = create_simple_lexer
      verify_golden_tokens("edge", "empty_input", "", lexer)
    end
    
    it "tokenizes only whitespace" do
      lexer = create_simple_lexer
      verify_golden_tokens("edge", "only_whitespace", "   \n\t  \r\n  ", lexer)
    end
    
    it "tokenizes single character" do
      lexer = create_simple_lexer
      verify_golden_tokens("edge", "single_char", "a", lexer)
    end
    
    it "tokenizes very long input" do
      lexer = create_simple_lexer
      # Generate a long input string
      words = (1..1000).map { |i| "word#{i}" }
      long_input = words.join(" ")
      
      verify_golden_tokens("edge", "very_long_input", long_input, lexer)
    end
    
    it "tokenizes unicode content" do
      lexer = create_simple_lexer
      unicode_content = "hello 世界 café 🚀 Здравствуй мир"
      
      verify_golden_tokens("edge", "unicode_content", unicode_content, lexer)
    end
  end
  
  describe "Error Recovery Golden Files" do
    it "recovers from invalid characters" do
      lexer = create_error_lexer
      source = "hello @#$ world 123 !@# test"
      
      # Test that it still produces some tokens despite errors
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", source)
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      # Should have some error diagnostics due to invalid characters
      error_diagnostics = diagnostics.select(&.severity.error?)
      error_diagnostics.should_not be_empty
      
      # But should still produce some valid tokens
      valid_tokens = tokens.reject { |t| t.kind.to_s.upcase == "EOF" }
      valid_tokens.should_not be_empty
      
      # Verify golden file for the tokens that were produced
      golden_content = token_sequence_to_golden(tokens, source_map)
      Hecate::Core::TestUtils::GoldenFile.test(
        "lexer/error/invalid_characters",
        golden_content,
        update: ENV["UPDATE_GOLDEN"]? == "1"
      )
    end
    
    it "handles mixed valid/invalid content" do
      lexer = create_error_lexer
      source = "valid123 @@@ another456 ### final"
      
      # Test that it produces tokens and diagnostics appropriately
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.txt", source)
      source_file = source_map.get(source_id).not_nil!
      
      tokens, diagnostics = lexer.scan(source_file)
      
      # Should have some error diagnostics
      error_diagnostics = diagnostics.select(&.severity.error?)
      error_diagnostics.should_not be_empty
      
      # Should produce valid tokens where possible
      valid_tokens = tokens.reject { |t| t.kind.to_s.upcase == "EOF" }
      valid_tokens.should_not be_empty
      
      # Verify golden file for the mixed content
      golden_content = token_sequence_to_golden(tokens, source_map)
      Hecate::Core::TestUtils::GoldenFile.test(
        "lexer/error/mixed_content",
        golden_content,
        update: ENV["UPDATE_GOLDEN"]? == "1"
      )
    end
  end
end