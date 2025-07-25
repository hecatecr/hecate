#!/usr/bin/env crystal

# Main benchmark runner for Hecate performance testing
#
# Usage:
#   crystal run --release tools/bench/run_benchmarks.cr
#   crystal run --release tools/bench/run_benchmarks.cr -- --compare baseline.json
#   crystal run --release tools/bench/run_benchmarks.cr -- --save results.json

require "./benchmark"
require "hecate-core"
require "hecate-lex"

include Hecate::Benchmark

def main
  puts "🚀 Hecate Performance Benchmark Suite"
  puts "======================================"
  puts ""

  runner = Runner.new(warmup_iterations: 3, benchmark_iterations: 30)

  # Parse command line arguments
  save_file = nil
  compare_file = nil

  i = 0
  while i < ARGV.size
    case ARGV[i]
    when "--save"
      save_file = ARGV[i + 1]
      i += 2
    when "--compare"
      compare_file = ARGV[i + 1]
      i += 2
    else
      i += 1
    end
  end

  # Run all benchmark suites
  run_core_benchmarks(runner)
  run_lexer_benchmarks(runner)

  # Save results if requested
  if save_file
    runner.save_results(save_file)
  end

  # Compare with baseline if requested
  if compare_file
    runner.compare_with_baseline(compare_file)
  end

  puts "✅ Benchmark suite completed!"
end

def run_core_benchmarks(runner : Runner)
  puts "📊 Core Component Benchmarks"
  puts "============================\n"

  # SourceFile position conversion benchmark
  source_content = Fixtures.generate_javascript(1000)
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("benchmark.js", source_content)

  runner.throughput_benchmark("SourceFile position conversion", 10_000) do
    10_000.times do |i|
      pos = i % source_content.bytesize
      source_map.get(source_id).not_nil!.byte_to_position(pos)
    end
  end

  # Span creation and manipulation
  runner.throughput_benchmark("Span creation and manipulation", 100_000) do
    100_000.times do |i|
      span = Hecate::Core::Span.new(source_id, i, i + 10)
      span.length
    end
  end

  # Diagnostic creation with multiple labels
  runner.throughput_benchmark("Diagnostic creation (complex)", 10_000) do
    10_000.times do |i|
      span1 = Hecate::Core::Span.new(source_id, i, i + 5)
      span2 = Hecate::Core::Span.new(source_id, i + 10, i + 15)

      diag = Hecate::Core.error("test error #{i}")
        .primary(span1, "primary label")
        .secondary(span2, "secondary label")
        .help("try this fix")
        .build
    end
  end

  puts ""
end

def run_lexer_benchmarks(runner : Runner)
  puts "🔤 Lexer Component Benchmarks"
  puts "=============================\n"

  # Simple JSON lexer benchmark
  json_lexer = Hecate::Lex.define do
    token :LBrace, /\{/
    token :RBrace, /\}/
    token :LBracket, /\[/
    token :RBracket, /\]/
    token :Comma, /,/
    token :Colon, /:/
    token :String, /"([^"\\\\]|\\\\.)*"/
    token :Number, /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/
    token :True, /true/
    token :False, /false/
    token :Null, /null/
    token :WS, /\s+/, skip: true
  end

  # Test with different JSON sizes
  small_json = Fixtures.generate_json(:small)
  medium_json = Fixtures.generate_json(:medium)
  large_json = Fixtures.generate_json(:large)

  # Count tokens for throughput calculation
  small_tokens = count_tokens(json_lexer, small_json)
  medium_tokens = count_tokens(json_lexer, medium_json)
  large_tokens = count_tokens(json_lexer, large_json)

  puts "JSON sizes: small=#{small_json.bytesize}B (#{small_tokens} tokens), " \
       "medium=#{medium_json.bytesize}B (#{medium_tokens} tokens), " \
       "large=#{large_json.bytesize}B (#{large_tokens} tokens)"
  puts ""

  # Small JSON benchmark
  result = runner.throughput_benchmark("JSON lexer (small)", small_tokens) do
    tokens, diagnostics = json_lexer.scan(small_json)
  end
  puts "  Tokens/second: #{format_throughput(result.tokens_per_second(small_tokens))}"
  puts ""

  # Medium JSON benchmark
  result = runner.throughput_benchmark("JSON lexer (medium)", medium_tokens) do
    tokens, diagnostics = json_lexer.scan(medium_json)
  end
  puts "  Tokens/second: #{format_throughput(result.tokens_per_second(medium_tokens))}"
  puts ""

  # Large JSON benchmark
  result = runner.throughput_benchmark("JSON lexer (large)", large_tokens) do
    tokens, diagnostics = json_lexer.scan(large_json)
  end
  puts "  Tokens/second: #{format_throughput(result.tokens_per_second(large_tokens))}"
  puts ""

  # JavaScript-like lexer benchmark
  js_content = Fixtures.generate_javascript(500)

  js_lexer = Hecate::Lex.define do
    # Keywords
    token :Function, /function/
    token :Const, /const/
    token :Let, /let/
    token :Return, /return/
    token :If, /if/
    token :Export, /export/

    # Operators and punctuation
    token :Plus, /\+/
    token :Minus, /-/
    token :Equals, /=/
    token :LParen, /\(/
    token :RParen, /\)/
    token :LBrace, /\{/
    token :RBrace, /\}/
    token :Semicolon, /;/
    token :Comma, /,/

    # Literals
    token :Number, /\d+/
    token :String, /'([^'\\\\]|\\\\.)*'/
    token :Identifier, /[a-zA-Z_][a-zA-Z0-9_]*/

    # Comments and whitespace
    token :Comment, /\/\/.*$/, skip: true
    token :WS, /\s+/, skip: true
  end

  js_tokens = count_tokens(js_lexer, js_content)

  result = runner.throughput_benchmark("JavaScript lexer", js_tokens) do
    tokens, diagnostics = js_lexer.scan(js_content)
  end
  puts "  Tokens/second: #{format_throughput(result.tokens_per_second(js_tokens))}"
  puts ""

  # Memory usage test
  runner.memory_benchmark("Large JSON lexing (memory)") do
    10.times do
      large_json = Fixtures.generate_json(:large)
      tokens, diagnostics = json_lexer.scan(large_json)
    end
  end
end

def count_tokens(lexer, input : String) : Int32
  tokens, _ = lexer.scan(input)
  tokens.size
end

def format_throughput(tps : Float64) : String
  if tps >= 1_000_000
    "#{(tps / 1_000_000).round(2)}M"
  elsif tps >= 1_000
    "#{(tps / 1_000).round(2)}K"
  else
    tps.round(1).to_s
  end
end

# Run the benchmark suite
main
