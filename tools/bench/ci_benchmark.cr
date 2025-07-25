#!/usr/bin/env crystal

# Continuous integration benchmark runner
#
# This script runs a subset of benchmarks suitable for CI environments
# and compares results against baseline to detect performance regressions.

# CI benchmark should be run from hecate-lex directory to avoid path issues
# Usage: cd shards/hecate-lex && crystal run --release ../../tools/bench/ci_benchmark.cr

require "./benchmark"
require "hecate-lex"

include Hecate::Benchmark

def main
  puts "🔄 CI Performance Benchmark"
  puts "===========================\n"

  # Quick benchmarks suitable for CI
  runner = Runner.new(warmup_iterations: 1, benchmark_iterations: 5)

  # Run core performance tests
  run_ci_benchmarks(runner)

  # Save timestamped results
  timestamp = Time.utc.to_s("%Y%m%d_%H%M%S")
  results_file = "results/ci_benchmark_#{timestamp}.json"
  runner.save_results(results_file)

  # Compare with baseline if it exists
  baseline_file = "results/baseline.json"
  if File.exists?(baseline_file)
    puts "\n📊 Performance Comparison"
    puts "========================="
    runner.compare_with_baseline(baseline_file)
  else
    puts "\n📌 No baseline found. Set this run as baseline:"
    puts "   cp #{results_file} #{baseline_file}"
  end

  puts "\n✅ CI benchmark completed!"
end

def run_ci_benchmarks(runner : Runner)
  # Fast core benchmarks for regression detection

  # 1. Simple lexer baseline
  simple_lexer = Hecate::Lex.define do |ctx|
    ctx.token :WORD, /\w+/
    ctx.token :WS, /\s+/, skip: true
  end

  benchmark_lexer(runner, simple_lexer, "CI: Simple lexer", "hello world test " * 50)

  # 2. JSON lexer (realistic complexity)
  json_lexer = Hecate::Lex.define do |ctx|
    ctx.token :LBRACE, /\{/, priority: 20
    ctx.token :RBRACE, /\}/, priority: 20
    ctx.token :STRING, /"[^"]*"/, priority: 10
    ctx.token :NUMBER, /\d+/, priority: 10
    ctx.token :TRUE, /true/, priority: 15
    ctx.token :FALSE, /false/, priority: 15
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  json_content = Fixtures.generate_json(:small)
  benchmark_lexer(runner, json_lexer, "CI: JSON lexer", json_content)

  # 3. Programming language lexer
  prog_lexer = Hecate::Lex.define do |ctx|
    ctx.token :IF, /if/, priority: 20
    ctx.token :FUNCTION, /function/, priority: 20
    ctx.token :IDENTIFIER, /[a-zA-Z_]\w*/, priority: 5
    ctx.token :NUMBER, /\d+/, priority: 10
    ctx.token :STRING, /"[^"]*"/, priority: 10
    ctx.token :LPAREN, /\(/, priority: 15
    ctx.token :RPAREN, /\)/, priority: 15
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  prog_content = generate_simple_program(25)
  benchmark_lexer(runner, prog_lexer, "CI: Programming lexer", prog_content)
end

def benchmark_lexer(runner : Runner, lexer, name : String, content : String)
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("ci_test.code", content)
  source_file = source_map.get(source_id).not_nil!

  # Count tokens
  tokens, _ = lexer.scan(source_file)
  token_count = tokens.size

  # Benchmark
  result = runner.throughput_benchmark(name, token_count) do
    benchmark_source_map = Hecate::Core::SourceMap.new
    benchmark_source_id = benchmark_source_map.add_file("benchmark.code", content)
    benchmark_source_file = benchmark_source_map.get(benchmark_source_id).not_nil!
    benchmark_tokens, benchmark_diagnostics = lexer.scan(benchmark_source_file)
  end

  tps = result.tokens_per_second(token_count)
  puts "  → #{format_throughput(tps)} tokens/sec"

  # Performance thresholds for CI
  if tps < 5_000
    puts "  ❌ PERFORMANCE REGRESSION: Below 5K tokens/sec minimum"
    exit(1) # Fail CI build
  elsif tps < 10_000
    puts "  ⚠️  Performance warning: Below 10K tokens/sec"
  else
    puts "  ✅ Performance acceptable"
  end

  puts ""
end

def generate_simple_program(lines : Int32) : String
  String.build do |str|
    str << "function test() {\n"
    lines.times do |i|
      str << "  if (condition#{i}) {\n"
      str << "    value#{i} = #{i};\n"
      str << "  }\n"
    end
    str << "}\n"
  end
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

main if PROGRAM_NAME == __FILE__
