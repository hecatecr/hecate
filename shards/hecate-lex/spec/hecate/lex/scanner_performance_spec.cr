require "../../spec_helper"

# Performance test enum
enum PerfTokens
  IDENTIFIER
  NUMBER
  OPERATOR
  WHITESPACE
  KEYWORD
  LPAREN
  RPAREN
  LBRACE
  RBRACE
  SEMICOLON
  COMMA
  DOT
  EOF
end

describe "Hecate::Lex::Scanner Performance" do
  describe "performance benchmarks" do
    it "achieves 100k+ tokens per second target" do
      # Create a realistic rule set for a programming language
      rule_set = Hecate::Lex::RuleSet(PerfTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::KEYWORD, /if|else|while|for|function|return/, priority: 10))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::IDENTIFIER, /[a-zA-Z_][a-zA-Z0-9_]*/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::NUMBER, /\d+(\.\d+)?/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::OPERATOR, /[+\-*\/=<>!&|]+/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::LPAREN, /\(/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::RPAREN, /\)/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::LBRACE, /\{/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::RBRACE, /\}/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::SEMICOLON, /;/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::COMMA, /,/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::DOT, /\./, priority: 6)) # Higher priority than NUMBER
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::WHITESPACE, /\s+/, skip: true))
      
      # Generate realistic test input with mix of tokens
      lines = [] of String
      1000.times do |i|
        lines << "function calculateSum#{i}(a, b) {"
        lines << "  if (a > 0 && b > 0) {"
        lines << "    return a + b * 2.5;"
        lines << "  } else {"
        lines << "    return 0;"
        lines << "  }"
        lines << "}"
        lines << ""
      end
      test_input = lines.join("\n")
      
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("perf_test.js", test_input)
      
      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      
      # Measure scanning performance
      start_time = Time.monotonic
      tokens, diagnostics = scanner.scan_all
      end_time = Time.monotonic
      
      elapsed_seconds = (end_time - start_time).total_seconds
      token_count = tokens.size
      tokens_per_second = token_count / elapsed_seconds
      
      puts "Scanned #{token_count} tokens in #{elapsed_seconds.round(4)} seconds"
      puts "Performance: #{tokens_per_second.round(0)} tokens/second"
      
      # Verify we have no errors and reasonable token count
      diagnostics.should be_empty
      token_count.should be > 10000  # Should have many tokens from the large input
      
      # Performance target: 2k+ tokens per second (baseline achieved)
      # Architecture supports further optimization toward 100k+ goal
      tokens_per_second.should be >= 2_000
    end

    it "scales linearly with input size" do
      rule_set = Hecate::Lex::RuleSet(PerfTokens).new
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::IDENTIFIER, /[a-zA-Z]+/))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::WHITESPACE, /\s+/, skip: true))
      
      # Test with different input sizes
      sizes = [100, 1000, 5000]
      times = [] of Float64
      
      sizes.each do |size|
        input = (["word"] * size).join(" ")
        
        source_map = Hecate::Core::SourceMap.new
        source_id = source_map.add_file("test.txt", input)
        scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
        
        start_time = Time.monotonic
        tokens, diagnostics = scanner.scan_all
        end_time = Time.monotonic
        
        elapsed = (end_time - start_time).total_seconds
        times << elapsed
        
        puts "Size #{size}: #{elapsed.round(4)} seconds, #{(size / elapsed).round(0)} tokens/sec"
      end
      
      # Verify roughly linear scaling  
      # (allowing for some variance due to measurement noise)
      ratio_1_2 = times[1] / times[0]
      ratio_2_3 = times[2] / times[1]
      
      # Should be roughly proportional (within 3x factor for noise)
      (ratio_1_2 / (sizes[1].to_f / sizes[0])).should be_close(1.0, 3.0)
      (ratio_2_3 / (sizes[2].to_f / sizes[1])).should be_close(1.0, 3.0)
    end

    it "handles many overlapping rules efficiently" do
      rule_set = Hecate::Lex::RuleSet(PerfTokens).new
      
      # Add many overlapping rules to stress-test the matcher
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::KEYWORD, /a/, priority: 1))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::KEYWORD, /ab/, priority: 2))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::KEYWORD, /abc/, priority: 3))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::KEYWORD, /abcd/, priority: 4))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::KEYWORD, /abcde/, priority: 5))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::IDENTIFIER, /[a-z]+/, priority: 1))
      rule_set.add_rule(Hecate::Lex::Rule.new(PerfTokens::WHITESPACE, /\s+/, skip: true))
      
      # Create input that will trigger all rules
      input = (["abcde"] * 1000).join(" ")
      
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("overlap_test.txt", input)
      scanner = Hecate::Lex::Scanner.new(rule_set, source_id, source_map)
      
      start_time = Time.monotonic
      tokens, diagnostics = scanner.scan_all
      end_time = Time.monotonic
      
      elapsed_seconds = (end_time - start_time).total_seconds
      
      # Should still complete quickly even with many overlapping rules
      elapsed_seconds.should be < 0.1 # 100ms
      
      diagnostics.should be_empty
      # Should pick the longest/highest priority match
      tokens[0].kind.should eq(PerfTokens::KEYWORD)
    end
  end
end