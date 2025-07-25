#!/usr/bin/env crystal

# Comprehensive lexer benchmarks that can be run from project root
# Usage: crystal run --release tools/bench/comprehensive_lexer_bench.cr

require "./tools/bench/benchmark"
require "./shards/hecate-lex/src/hecate-lex"

include Hecate::Benchmark

def main
  puts "🚀 Hecate Comprehensive Lexer Benchmarks"
  puts "========================================"
  puts ""

  runner = Runner.new(warmup_iterations: 2, benchmark_iterations: 10)

  run_performance_suite(runner)

  # Save results
  results_dir = "tools/bench/results"
  Dir.mkdir_p(results_dir) unless Dir.exists?(results_dir)
  runner.save_results("#{results_dir}/comprehensive_lexer_results.json")

  puts "\n🎯 Comprehensive Performance Analysis Complete!"
  puts "=============================================="
  puts "📊 Results saved to: tools/bench/results/comprehensive_lexer_results.json"
end

def run_performance_suite(runner : Runner)
  test_simple_lexers(runner)
  test_json_performance(runner)
  test_programming_languages(runner)
  test_scaling_characteristics(runner)
end

def test_simple_lexers(runner : Runner)
  puts "📊 Simple Lexer Performance"
  puts "===========================\n"

  # Basic word tokenizer
  word_lexer = Hecate::Lex.define do |ctx|
    ctx.token :WORD, /\w+/
    ctx.token :WS, /\s+/, skip: true
  end

  test_cases = [
    {"tiny", "hello world test"},
    {"small", "word " * 100},
    {"medium", "identifier " * 1000},
    {"large", "token " * 5000},
  ]

  test_cases.each do |test_case|
    size, content = test_case
    benchmark_lexer(runner, word_lexer, "Word lexer (#{size})", content)
  end
end

def test_json_performance(runner : Runner)
  puts "📊 JSON Lexer Performance"
  puts "=========================\n"

  json_lexer = Hecate::Lex.define do |ctx|
    ctx.token :LBRACE, /\{/, priority: 20
    ctx.token :RBRACE, /\}/, priority: 20
    ctx.token :LBRACKET, /\[/, priority: 20
    ctx.token :RBRACKET, /\]/, priority: 20
    ctx.token :COMMA, /,/, priority: 20
    ctx.token :COLON, /:/, priority: 20
    ctx.token :TRUE, /true/, priority: 15
    ctx.token :FALSE, /false/, priority: 15
    ctx.token :NULL, /null/, priority: 15
    ctx.token :STRING, /"([^"\\\\]|\\\\.)*"/, priority: 10
    ctx.token :NUMBER, /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/, priority: 10
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  json_cases = [
    {"simple", Fixtures.generate_json(:small)},
    {"complex", Fixtures.generate_json(:medium)},
    {"nested", Fixtures.generate_json(:large)},
  ]

  json_cases.each do |json_case|
    complexity, content = json_case
    benchmark_lexer(runner, json_lexer, "JSON lexer (#{complexity})", content)
  end
end

def test_programming_languages(runner : Runner)
  puts "📊 Programming Language Lexer Performance"
  puts "=========================================\n"

  # JavaScript-like lexer with comprehensive tokens
  js_lexer = Hecate::Lex.define do |ctx|
    # Keywords (highest priority)
    ctx.token :FUNCTION, /function/, priority: 25
    ctx.token :CONST, /const/, priority: 25
    ctx.token :LET, /let/, priority: 25
    ctx.token :VAR, /var/, priority: 25
    ctx.token :IF, /if/, priority: 25
    ctx.token :ELSE, /else/, priority: 25
    ctx.token :WHILE, /while/, priority: 25
    ctx.token :FOR, /for/, priority: 25
    ctx.token :RETURN, /return/, priority: 25

    # Multi-character operators
    ctx.token :ARROW, /=>/, priority: 20
    ctx.token :EQ, /==/, priority: 20
    ctx.token :NE, /!=/, priority: 20
    ctx.token :LE, /<=/, priority: 20
    ctx.token :GE, />=/, priority: 20

    # Single-character operators and punctuation
    ctx.token :ASSIGN, /=/, priority: 15
    ctx.token :PLUS, /\+/, priority: 15
    ctx.token :MINUS, /-/, priority: 15
    ctx.token :STAR, /\*/, priority: 15
    ctx.token :SLASH, /\//, priority: 15
    ctx.token :LPAREN, /\(/, priority: 15
    ctx.token :RPAREN, /\)/, priority: 15
    ctx.token :LBRACE, /\{/, priority: 15
    ctx.token :RBRACE, /\}/, priority: 15
    ctx.token :SEMICOLON, /;/, priority: 15
    ctx.token :COMMA, /,/, priority: 15

    # Literals
    ctx.token :NUMBER, /\d+(?:\.\d+)?/, priority: 10
    ctx.token :STRING, /'([^'\\\\]|\\\\.)*'|"([^"\\\\]|\\\\.)*"/, priority: 10
    ctx.token :IDENTIFIER, /[a-zA-Z_$][a-zA-Z0-9_$]*/, priority: 5

    # Whitespace and comments
    ctx.token :LINE_COMMENT, /\/\/.*$/, skip: true, priority: 1
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  js_cases = [
    {"function", generate_function_code(25)},
    {"class", generate_class_code(50)},
    {"expressions", generate_expression_code(75)},
  ]

  js_cases.each do |js_case|
    type, content = js_case
    benchmark_lexer(runner, js_lexer, "JavaScript lexer (#{type})", content)
  end
end

def test_scaling_characteristics(runner : Runner)
  puts "📊 Scaling Performance Analysis"
  puts "===============================\n"

  # Scaling test lexer
  scaling_lexer = Hecate::Lex.define do |ctx|
    ctx.token :KEYWORD, /if|then|else|while|for/, priority: 10
    ctx.token :IDENTIFIER, /[a-zA-Z_]\w*/, priority: 5
    ctx.token :NUMBER, /\d+/, priority: 5
    ctx.token :OPERATOR, /[+\-*\/=<>!]+/, priority: 5
    ctx.token :PUNCT, /[(){}[\];,.]/, priority: 5
    ctx.token :WS, /\s+/, skip: true, priority: 1
  end

  # Test different input sizes
  [500, 1000, 2500, 5000, 10000].each do |target_tokens|
    content = generate_scaling_code(target_tokens // 4) # ~4 tokens per line
    actual_tokens = count_tokens(scaling_lexer, content)

    result = runner.throughput_benchmark("Scaling (#{actual_tokens} tokens)", actual_tokens) do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("scaling_#{actual_tokens}.test", content)
      source_file = source_map.get(source_id).not_nil!
      tokens, diagnostics = scaling_lexer.scan(source_file)
    end

    tps = result.tokens_per_second(actual_tokens)
    bytes_per_sec = (content.bytesize / result.mean).to_i

    puts "  Size: #{content.bytesize}B, Tokens: #{actual_tokens}"
    puts "  → #{format_throughput(tps)} tokens/sec"
    puts "  → #{format_throughput(bytes_per_sec.to_f)} bytes/sec"

    # Performance assessment with scaling context
    if tps >= 100_000
      puts "  🚀 Excellent scaling performance!"
    elsif tps >= 50_000
      puts "  ✅ Good scaling performance"
    elsif tps >= 10_000
      puts "  📈 Acceptable scaling (meets 10K minimum)"
    else
      puts "  ⚠️  Scaling below 10K tokens/sec target"
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

  # Performance thresholds
  if tps >= 100_000
    puts "  🚀 Outstanding! Exceeds 100K target"
  elsif tps >= 50_000
    puts "  ✅ Excellent performance"
  elsif tps >= 10_000
    puts "  📈 Good performance"
  else
    puts "  ⚠️  Below performance expectations"
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

# Code generators
def generate_function_code(lines : Int32) : String
  String.build do |str|
    str << "function testFunction() {\n"
    lines.times do |i|
      str << "  const value#{i} = #{i} + #{i * 2};\n"
      str << "  if (value#{i} > 10) return value#{i};\n"
    end
    str << "}\n"
  end
end

def generate_class_code(lines : Int32) : String
  String.build do |str|
    str << "class TestClass {\n"
    str << "  constructor() { this.data = []; }\n"
    (lines // 3).times do |i|
      str << "  method#{i}(param) {\n"
      str << "    return param + #{i};\n"
      str << "  }\n"
    end
    str << "}\n"
  end
end

def generate_expression_code(lines : Int32) : String
  String.build do |str|
    lines.times do |i|
      str << "result#{i} = (a#{i} + b#{i}) * c#{i} / #{i + 1};\n"
    end
  end
end

def generate_scaling_code(lines : Int32) : String
  String.build do |str|
    lines.times do |i|
      case i % 4
      when 0
        str << "if (condition#{i}) {\n"
      when 1
        str << "  value#{i} = process(#{i});\n"
      when 2
        str << "  result = value#{i} + #{i};\n"
      when 3
        str << "}\n"
      end
    end
  end
end

main
