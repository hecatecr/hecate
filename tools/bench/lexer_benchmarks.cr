#!/usr/bin/env crystal

# Comprehensive lexer benchmarks for Hecate
#
# Tests various lexer configurations against different input sizes
# and complexity to establish performance baselines and detect regressions.

require "./benchmark"

# Add the src paths for proper require resolution
require "hecate-core"
require "hecate-lex"

HECATE_ROOT = Path[__DIR__].join("../..")

include Hecate::Benchmark

def main
  puts "🚀 Hecate Lexer Performance Benchmarks"
  puts "======================================="
  puts ""

  runner = Runner.new(warmup_iterations: 3, benchmark_iterations: 15)

  # Save baseline results
  run_all_benchmarks(runner)

  # Save results
  runner.save_results("#{HECATE_ROOT}/tools/bench/results/lexer_baseline.json")

  puts "\n🎯 Performance Summary"
  puts "====================="
  puts "✅ Benchmarking completed!"
  puts "📊 Results saved to: tools/bench/results/lexer_baseline.json"
end

def run_all_benchmarks(runner : Runner)
  # Test suite progression: simple → realistic → complex
  run_simple_lexer_benchmarks(runner)
  run_json_lexer_benchmarks(runner)
  run_programming_language_benchmarks(runner)
  run_scaling_benchmarks(runner)
end

def run_simple_lexer_benchmarks(runner : Runner)
  puts "📊 Simple Lexer Benchmarks"
  puts "==========================\n"

  # Minimal lexer - baseline performance
  minimal_lexer = Hecate::Lex.define do |ctx|
    ctx.token :WORD, /\w+/
    ctx.token :WS, /\s+/, skip: true
  end

  test_inputs = {
    "tiny"   => "hello world",
    "small"  => "the quick brown fox jumps over the lazy dog " * 10,
    "medium" => "word " * 1000,
    "large"  => "identifier " * 10000,
  }

  test_inputs.each do |size, content|
    benchmark_lexer(runner, minimal_lexer, "Minimal lexer (#{size})", content)
  end

  puts ""
end

def run_json_lexer_benchmarks(runner : Runner)
  puts "📊 JSON Lexer Benchmarks"
  puts "========================\n"

  # Realistic JSON lexer
  json_lexer = Hecate::Lex.define do |ctx|
    # Punctuation (higher priority)
    ctx.token :LBRACE, /\{/, priority: 20
    ctx.token :RBRACE, /\}/, priority: 20
    ctx.token :LBRACKET, /\[/, priority: 20
    ctx.token :RBRACKET, /\]/, priority: 20
    ctx.token :COMMA, /,/, priority: 20
    ctx.token :COLON, /:/, priority: 20

    # Keywords (must beat string matching)
    ctx.token :TRUE, /true/, priority: 15
    ctx.token :FALSE, /false/, priority: 15
    ctx.token :NULL, /null/, priority: 15

    # Complex patterns
    ctx.token :STRING, /"([^"\\\\]|\\\\.)*"/, priority: 10
    ctx.token :NUMBER, /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/, priority: 10

    # Whitespace
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  # Test with generated JSON of various complexities
  json_inputs = {
    "simple"  => Fixtures.generate_json(:small),
    "nested"  => Fixtures.generate_json(:medium),
    "complex" => Fixtures.generate_json(:large),
  }

  json_inputs.each do |complexity, content|
    benchmark_lexer(runner, json_lexer, "JSON lexer (#{complexity})", content)
  end

  puts ""
end

def run_programming_language_benchmarks(runner : Runner)
  puts "📊 Programming Language Lexer Benchmarks"
  puts "========================================\n"

  # JavaScript-like lexer with comprehensive token set
  js_lexer = Hecate::Lex.define do |ctx|
    # Keywords (highest priority to beat identifier matching)
    %w[function const let var if else while for return import export class extends].each do |keyword|
      ctx.token keyword.upcase.to_sym, /#{keyword}/, priority: 25
    end

    # Multi-character operators (beat single-char versions)
    ctx.token :ARROW, /=>/, priority: 20
    ctx.token :EQ, /==/, priority: 20
    ctx.token :NE, /!=/, priority: 20
    ctx.token :LE, /<=/, priority: 20
    ctx.token :GE, />=/, priority: 20
    ctx.token :AND, /&&/, priority: 20
    ctx.token :OR, /\|\|/, priority: 20
    ctx.token :INCR, /\+\+/, priority: 20
    ctx.token :DECR, /--/, priority: 20

    # Single-character operators
    ctx.token :PLUS, /\+/, priority: 15
    ctx.token :MINUS, /-/, priority: 15
    ctx.token :STAR, /\*/, priority: 15
    ctx.token :SLASH, /\//, priority: 15
    ctx.token :PERCENT, /%/, priority: 15
    ctx.token :ASSIGN, /=/, priority: 15
    ctx.token :LT, /</, priority: 15
    ctx.token :GT, />/, priority: 15
    ctx.token :NOT, /!/, priority: 15

    # Punctuation
    ctx.token :LPAREN, /\(/, priority: 15
    ctx.token :RPAREN, /\)/, priority: 15
    ctx.token :LBRACE, /\{/, priority: 15
    ctx.token :RBRACE, /\}/, priority: 15
    ctx.token :LBRACKET, /\[/, priority: 15
    ctx.token :RBRACKET, /\]/, priority: 15
    ctx.token :SEMICOLON, /;/, priority: 15
    ctx.token :COMMA, /,/, priority: 15
    ctx.token :DOT, /\./, priority: 15

    # Literals (complex patterns)
    ctx.token :NUMBER, /\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/, priority: 10
    ctx.token :STRING, /'([^'\\\\]|\\\\.)*'|"([^"\\\\]|\\\\.)*"/, priority: 10
    ctx.token :TEMPLATE, /`([^`\\\\]|\\\\.)*`/, priority: 10

    # Identifiers (lowest priority)
    ctx.token :IDENTIFIER, /[a-zA-Z_$][a-zA-Z0-9_$]*/, priority: 5

    # Comments and whitespace
    ctx.token :LINE_COMMENT, /\/\/.*$/, skip: true, priority: 1
    ctx.token :BLOCK_COMMENT, /\/\*.*?\*\//, skip: true, priority: 1
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  # Test with realistic programming language code
  js_inputs = {
    "function" => generate_function_code(50),
    "class"    => generate_class_code(100),
    "module"   => generate_module_code(200),
  }

  js_inputs.each do |type, content|
    benchmark_lexer(runner, js_lexer, "JavaScript lexer (#{type})", content)
  end

  puts ""
end

def run_scaling_benchmarks(runner : Runner)
  puts "📊 Lexer Scaling Benchmarks"
  puts "===========================\n"

  # Simple but consistent lexer for scaling tests
  scaling_lexer = Hecate::Lex.define do |ctx|
    ctx.token :KEYWORD, /if|then|else|while|for/, priority: 10
    ctx.token :IDENTIFIER, /[a-zA-Z_]\w*/, priority: 5
    ctx.token :NUMBER, /\d+/, priority: 5
    ctx.token :OPERATOR, /[+\-*\/=<>!]+/, priority: 5
    ctx.token :PUNCT, /[(){}[\];,.]/, priority: 5
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  # Test scaling with different input sizes
  scaling_sizes = [100, 500, 1000, 5000, 10000]

  scaling_sizes.each do |line_count|
    content = generate_scaling_code(line_count)
    token_count = count_tokens(scaling_lexer, content)

    result = runner.throughput_benchmark("Scaling test (#{line_count} lines)", token_count) do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("scaling_#{line_count}.code", content)
      source_file = source_map.get(source_id).not_nil!
      tokens, diagnostics = scaling_lexer.scan(source_file)
    end

    tps = result.tokens_per_second(token_count)
    bytes_per_sec = (content.bytesize / result.mean).to_i

    puts "  Lines: #{line_count}, Tokens: #{token_count}, Bytes: #{content.bytesize}"
    puts "  → #{format_throughput(tps)} tokens/sec, #{format_throughput(bytes_per_sec.to_f)} bytes/sec"

    # Performance thresholds
    if tps >= 100_000
      puts "  🚀 Excellent scaling performance!"
    elsif tps >= 50_000
      puts "  ✅ Good scaling performance"
    elsif tps >= 10_000
      puts "  📈 Acceptable scaling performance"
    else
      puts "  ⚠️  Scaling performance below target"
    end
    puts ""
  end
end

# Helper functions
def benchmark_lexer(runner : Runner, lexer, name : String, content : String)
  token_count = count_tokens(lexer, content)

  result = runner.throughput_benchmark(name, token_count) do
    source_map = Hecate::Core::SourceMap.new
    source_id = source_map.add_file("#{name.downcase.gsub(/[^a-z0-9]/, "_")}.test", content)
    source_file = source_map.get(source_id).not_nil!
    tokens, diagnostics = lexer.scan(source_file)
  end

  tps = result.tokens_per_second(token_count)
  puts "  Size: #{content.bytesize}B, Tokens: #{token_count}"
  puts "  → #{format_throughput(tps)} tokens/sec"

  # Performance assessment
  if tps >= 100_000
    puts "  🚀 Outstanding performance!"
  elsif tps >= 50_000
    puts "  ✅ Excellent performance"
  elsif tps >= 10_000
    puts "  📈 Good performance"
  else
    puts "  ⚠️  Below performance target"
  end
  puts ""
end

def count_tokens(lexer, input : String) : Int32
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("count.test", input)
  source_file = source_map.get(source_id).not_nil!

  tokens, _ = lexer.scan(source_file)
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

# Code generators for realistic testing
def generate_function_code(line_count : Int32) : String
  String.build do |str|
    str << "// Generated function code for benchmarking\n"
    str << "function fibonacci(n) {\n"
    str << "  if (n <= 1) return n;\n"
    str << "  return fibonacci(n - 1) + fibonacci(n - 2);\n"
    str << "}\n\n"

    line_count.times do |i|
      str << "const result#{i} = fibonacci(#{i % 20});\n"
      str << "console.log(`Result ${i}: ${result#{i}}`);\n"

      if i % 10 == 0 && i > 0
        str << "\n// Checkpoint #{i}\n"
      end
    end

    str << "\nexport { fibonacci };\n"
  end
end

def generate_class_code(line_count : Int32) : String
  String.build do |str|
    str << "// Generated class code for benchmarking\n"
    str << "class Calculator {\n"
    str << "  constructor() {\n"
    str << "    this.operations = [];\n"
    str << "  }\n\n"

    (line_count // 4).times do |i|
      str << "  add#{i}(a, b) {\n"
      str << "    const result = a + b;\n"
      str << "    this.operations.push({ op: 'add', args: [a, b], result });\n"
      str << "    return result;\n"
      str << "  }\n\n"
    end

    str << "  getHistory() {\n"
    str << "    return this.operations;\n"
    str << "  }\n"
    str << "}\n\n"
    str << "export default Calculator;\n"
  end
end

def generate_module_code(line_count : Int32) : String
  String.build do |str|
    str << "// Generated module code for benchmarking\n"
    str << "import { EventEmitter } from 'events';\n"
    str << "import * as fs from 'fs';\n\n"

    (line_count // 6).times do |i|
      str << "export function process#{i}(data) {\n"
      str << "  if (!data || typeof data !== 'object') {\n"
      str << "    throw new Error('Invalid data provided');\n"
      str << "  }\n"
      str << "  return { ...data, processed: true, id: #{i} };\n"
      str << "}\n\n"
    end

    str << "export const VERSION = '1.0.0';\n"
    str << "export const CONSTANTS = { MAX_SIZE: 1000 };\n"
  end
end

def generate_scaling_code(line_count : Int32) : String
  String.build do |str|
    line_count.times do |i|
      case i % 5
      when 0
        str << "if (condition#{i}) {\n"
      when 1
        str << "  let value#{i} = calculate(#{i});\n"
      when 2
        str << "  result = value#{i} + #{i};\n"
      when 3
        str << "  process(result);\n"
      when 4
        str << "}\n"
      end
    end
  end
end

# Run the benchmarks
main if PROGRAM_NAME == __FILE__
