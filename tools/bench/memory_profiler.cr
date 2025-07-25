#!/usr/bin/env crystal

# Memory profiling tools for Hecate performance analysis
#
# Provides detailed memory usage analysis during lexing operations
# to identify allocation patterns and potential optimizations.

# Memory profiler should be run from hecate-lex directory to avoid path issues
# Usage: cd shards/hecate-lex && crystal run --release ../../tools/bench/memory_profiler.cr

require "./benchmark"
require "hecate-lex"

include Hecate::Benchmark

def main
  puts "🧠 Hecate Memory Profiling Analysis"
  puts "===================================\n"

  runner = Runner.new(warmup_iterations: 2, benchmark_iterations: 5)

  analyze_lexer_memory_usage(runner)
  analyze_memory_scaling(runner)

  puts "✅ Memory profiling completed!"
end

def analyze_lexer_memory_usage(runner : Runner)
  puts "📊 Lexer Memory Usage Analysis"
  puts "==============================\n"

  # Simple lexer for baseline
  simple_lexer = Hecate::Lex.define do |ctx|
    ctx.token :WORD, /\w+/
    ctx.token :WS, /\s+/, skip: true
  end

  # Complex lexer for comparison
  complex_lexer = Hecate::Lex.define do |ctx|
    ctx.token :FUNCTION, /function/, priority: 25
    ctx.token :CONST, /const/, priority: 25
    ctx.token :IF, /if/, priority: 25
    ctx.token :ELSE, /else/, priority: 25
    ctx.token :ARROW, /=>/, priority: 20
    ctx.token :EQ, /==/, priority: 20
    ctx.token :STRING, /"([^"\\\\]|\\\\.)*"/, priority: 10
    ctx.token :NUMBER, /\d+(?:\.\d+)?/, priority: 10
    ctx.token :IDENTIFIER, /[a-zA-Z_$][a-zA-Z0-9_$]*/, priority: 5
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  test_cases = [
    {"Simple content", "hello world test " * 100, simple_lexer},
    {"Complex content", generate_js_content(100), complex_lexer},
    {"Large simple", "token " * 5000, simple_lexer},
    {"Large complex", generate_js_content(500), complex_lexer},
  ]

  test_cases.each do |test_case|
    name, content, lexer = test_case["name"], test_case["content"], test_case["lexer"]
    profile_lexer_memory(runner, lexer, name, content)
  end
end

def analyze_memory_scaling(runner : Runner)
  puts "📊 Memory Scaling Analysis"
  puts "==========================\n"

  scaling_lexer = Hecate::Lex.define do |ctx|
    ctx.token :KEYWORD, /if|then|else|while|for/, priority: 10
    ctx.token :IDENTIFIER, /[a-zA-Z_]\w*/, priority: 5
    ctx.token :NUMBER, /\d+/, priority: 5
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  # Test memory usage at different scales
  sizes = [100, 500, 1000, 2500, 5000]

  sizes.each do |token_count|
    content = generate_scaling_content(token_count)
    profile_memory_scaling(runner, scaling_lexer, "Scaling (#{token_count} tokens)", content)
  end
end

def profile_lexer_memory(runner : Runner, lexer, name : String, content : String)
  puts "Memory profile: #{name}"
  puts "  Content size: #{content.bytesize} bytes"

  # Get token count first
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("profile.test", content)
  source_file = source_map.get(source_id).not_nil!
  tokens, _ = lexer.scan(source_file)

  puts "  Token count: #{tokens.size}"

  # Detailed memory profiling
  elapsed, memory_used, final_heap = runner.memory_benchmark("#{name} (detailed)") do
    # Create fresh source map for each iteration
    mem_source_map = Hecate::Core::SourceMap.new
    mem_source_id = mem_source_map.add_file("memory_profile.test", content)
    mem_source_file = mem_source_map.get(mem_source_id).not_nil!

    # Perform lexing
    mem_tokens, mem_diagnostics = lexer.scan(mem_source_file)
  end

  # Calculate memory efficiency metrics
  bytes_per_token = tokens.size > 0 ? memory_used.to_f / tokens.size : 0.0
  memory_ratio = content.bytesize > 0 ? memory_used.to_f / content.bytesize : 0.0

  puts "  Memory per token: #{bytes_per_token.round(2)} bytes"
  puts "  Memory overhead ratio: #{memory_ratio.round(2)}x input size"

  # Memory efficiency assessment
  if bytes_per_token < 100
    puts "  ✅ Excellent memory efficiency"
  elsif bytes_per_token < 500
    puts "  📈 Good memory efficiency"
  else
    puts "  ⚠️  High memory usage per token"
  end

  puts ""
end

def profile_memory_scaling(runner : Runner, lexer, name : String, content : String)
  puts "Memory scaling: #{name}"

  # Baseline measurement
  GC.collect
  initial_memory = GC.stats.heap_size

  # Create source file
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("scaling.test", content)
  source_file = source_map.get(source_id).not_nil!

  # Measure lexing memory
  start_time = Time.monotonic
  tokens, diagnostics = lexer.scan(source_file)
  end_time = Time.monotonic

  GC.collect
  final_memory = GC.stats.heap_size

  # Calculate metrics
  elapsed = (end_time - start_time).total_seconds
  memory_used = (final_memory - initial_memory).to_i64
  tokens_per_mb = memory_used > 0 ? (tokens.size.to_f / (memory_used / 1_048_576.0)).round : 0

  puts "  Tokens: #{tokens.size}, Time: #{format_time(elapsed)}"
  puts "  Memory used: #{format_bytes(memory_used)}"
  puts "  Throughput: #{format_number(tokens.size / elapsed)} tokens/sec"
  puts "  Efficiency: #{tokens_per_mb.round} tokens/MB"

  # Scaling assessment
  if tokens_per_mb >= 10_000
    puts "  🚀 Excellent memory scaling"
  elsif tokens_per_mb >= 5_000
    puts "  ✅ Good memory scaling"
  elsif tokens_per_mb >= 1_000
    puts "  📈 Acceptable memory scaling"
  else
    puts "  ⚠️  Memory scaling needs optimization"
  end

  puts ""
end

# Helper functions
def generate_js_content(line_count : Int32) : String
  String.build do |str|
    str << "function testCode() {\n"
    line_count.times do |i|
      str << "  const value#{i} = #{i} + #{i * 2};\n"
      str << "  if (value#{i} > 10) {\n"
      str << "    return value#{i};\n"
      str << "  }\n"
    end
    str << "}\n"
  end
end

def generate_scaling_content(target_tokens : Int32) : String
  # Estimate lines needed (roughly 4-5 tokens per line)
  line_count = target_tokens // 4

  String.build do |str|
    line_count.times do |i|
      case i % 4
      when 0
        str << "if condition#{i} then\n"
      when 1
        str << "  value#{i} = #{i}\n"
      when 2
        str << "  result = value#{i}\n"
      when 3
        str << "else\n"
      end
    end
  end
end

def format_time(seconds : Float64) : String
  if seconds < 0.001
    "#{(seconds * 1_000_000).round(1)}μs"
  elsif seconds < 1.0
    "#{(seconds * 1_000).round(1)}ms"
  else
    "#{seconds.round(3)}s"
  end
end

def format_bytes(bytes : Int64) : String
  if bytes >= 1_000_000
    "#{(bytes / 1_000_000.0).round(2)}MB"
  elsif bytes >= 1_000
    "#{(bytes / 1_000.0).round(2)}KB"
  else
    "#{bytes}B"
  end
end

def format_number(num : Float64) : String
  if num >= 1_000_000
    "#{(num / 1_000_000).round(2)}M"
  elsif num >= 1_000
    "#{(num / 1_000).round(2)}K"
  else
    num.round(1).to_s
  end
end

main if PROGRAM_NAME == __FILE__
