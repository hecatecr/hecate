# Benchmarking infrastructure for Hecate performance testing
#
# This module provides utilities for measuring and reporting performance
# across different components of the Hecate language toolkit.

require "json"
require "file_utils"

module Hecate::Benchmark
  VERSION = "0.1.0"

  # Statistical result from benchmark runs
  struct Result
    getter name : String
    getter unit : String
    getter mean : Float64
    getter std_dev : Float64
    getter min : Float64
    getter max : Float64
    getter iterations : Int32
    getter total_time : Float64

    def initialize(@name : String, @unit : String, @mean : Float64,
                   @std_dev : Float64, @min : Float64, @max : Float64,
                   @iterations : Int32, @total_time : Float64)
    end

    # Convert to tokens/second for lexer benchmarks
    def tokens_per_second(token_count : Int32)
      return 0.0 if mean == 0.0
      token_count / mean
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "name", name
        json.field "unit", unit
        json.field "mean", mean
        json.field "std_dev", std_dev
        json.field "min", min
        json.field "max", max
        json.field "iterations", iterations
        json.field "total_time", total_time
      end
    end
  end

  # Benchmark runner with statistical analysis
  class Runner
    @results = [] of Result

    def initialize(@warmup_iterations = 5, @benchmark_iterations = 50)
    end

    # Run a benchmark with statistical analysis
    def benchmark(name : String, unit = "seconds", &block : -> Nil) : Result
      puts "Warming up: #{name}..."

      # Warmup runs
      @warmup_iterations.times { block.call }

      puts "Benchmarking: #{name} (#{@benchmark_iterations} iterations)..."

      # Actual benchmark runs
      times = [] of Float64
      @benchmark_iterations.times do |i|
        start_time = Time.monotonic
        block.call
        end_time = Time.monotonic

        elapsed = (end_time - start_time).total_seconds
        times << elapsed

        if (i + 1) % 10 == 0
          puts "  Completed #{i + 1}/#{@benchmark_iterations} iterations"
        end
      end

      # Calculate statistics
      mean = times.sum / times.size
      variance = times.sum { |t| (t - mean) ** 2 } / times.size
      std_dev = Math.sqrt(variance)
      min = times.min
      max = times.max
      total_time = times.sum

      result = Result.new(name, unit, mean, std_dev, min, max, @benchmark_iterations, total_time)
      @results << result

      puts "  Mean: #{format_time(mean)}"
      puts "  Std Dev: #{format_time(std_dev)} (#{(std_dev / mean * 100).round(2)}%)"
      puts "  Range: #{format_time(min)} - #{format_time(max)}"
      puts ""

      result
    end

    # Benchmark with throughput calculation (items/second)
    def throughput_benchmark(name : String, item_count : Int32, &block : -> Nil) : Result
      result = benchmark("#{name} (#{item_count} items)") { block.call }

      throughput = item_count / result.mean
      puts "  Throughput: #{format_number(throughput)} items/second"
      puts ""

      result
    end

    # Memory usage benchmark
    def memory_benchmark(name : String, &block : -> Nil)
      puts "Memory benchmark: #{name}..."

      # Force GC before measurement
      GC.collect
      initial_memory = GC.stats.heap_size

      start_time = Time.monotonic
      block.call
      end_time = Time.monotonic

      # Force GC after to measure retained memory
      GC.collect
      final_memory = GC.stats.heap_size

      elapsed = (end_time - start_time).total_seconds
      memory_used = (final_memory - initial_memory).to_i64

      puts "  Time: #{format_time(elapsed)}"
      puts "  Memory used: #{format_bytes(memory_used)}"
      puts "  Final heap size: #{format_bytes(final_memory.to_i64)}"
      puts ""

      {elapsed, memory_used, final_memory}
    end

    # Save results to JSON file
    def save_results(filename : String)
      FileUtils.mkdir_p(File.dirname(filename))

      File.write(filename, @results.to_json)
      puts "Results saved to: #{filename}"
    end

    # Load and compare with previous results
    def compare_with_baseline(baseline_file : String)
      return unless File.exists?(baseline_file)

      baseline_json = File.read(baseline_file)
      baseline_results = Array(Result).from_json(baseline_json)

      puts "\n=== Performance Comparison ==="

      @results.each do |current|
        baseline = baseline_results.find { |b| b.name == current.name }
        next unless baseline

        improvement = ((baseline.mean - current.mean) / baseline.mean) * 100

        puts "#{current.name}:"
        puts "  Baseline: #{format_time(baseline.mean)}"
        puts "  Current:  #{format_time(current.mean)}"

        if improvement > 0
          puts "  Improvement: #{improvement.round(2)}% faster ✓"
        elsif improvement < -5 # Only warn on 5%+ regression
          puts "  Regression:  #{(-improvement).round(2)}% slower ⚠️"
        else
          puts "  Change: #{improvement.round(2)}% (within noise)"
        end
        puts ""
      end
    end

    private def format_time(seconds : Float64) : String
      if seconds < 0.001
        "#{(seconds * 1_000_000).round(1)}μs"
      elsif seconds < 1.0
        "#{(seconds * 1_000).round(1)}ms"
      else
        "#{seconds.round(3)}s"
      end
    end

    private def format_number(num : Float64) : String
      if num >= 1_000_000
        "#{(num / 1_000_000).round(2)}M"
      elsif num >= 1_000
        "#{(num / 1_000).round(2)}K"
      else
        num.round(1).to_s
      end
    end

    private def format_bytes(bytes : Int64) : String
      if bytes >= 1_000_000_000
        "#{(bytes / 1_000_000_000.0).round(2)}GB"
      elsif bytes >= 1_000_000
        "#{(bytes / 1_000_000.0).round(2)}MB"
      elsif bytes >= 1_000
        "#{(bytes / 1_000.0).round(2)}KB"
      else
        "#{bytes}B"
      end
    end
  end

  # Sample data generators for consistent benchmarking
  module Fixtures
    # Generate JSON test data of specified complexity
    def self.generate_json(size : Symbol = :medium) : String
      case size
      when :small
        generate_json_object(depth: 2, arrays: 1, objects: 3)
      when :medium
        generate_json_object(depth: 4, arrays: 3, objects: 10)
      when :large
        generate_json_object(depth: 6, arrays: 5, objects: 25)
      else
        generate_json_object(depth: 3, arrays: 2, objects: 7)
      end
    end

    # Generate JavaScript-like code for lexer testing
    def self.generate_javascript(lines : Int32 = 100) : String
      String.build do |str|
        str << "// Generated JavaScript test code\n"
        str << "function fibonacci(n) {\n"
        str << "  if (n <= 1) return n;\n"
        str << "  return fibonacci(n - 1) + fibonacci(n - 2);\n"
        str << "}\n\n"

        lines.times do |i|
          str << "const result#{i} = fibonacci(#{i % 20});\n"
          str << "console.log('Result #{i}:', result#{i});\n"

          if i % 10 == 0
            str << "\n// Checkpoint #{i}\n"
          end
        end

        str << "\nexport { fibonacci };\n"
      end
    end

    private def self.generate_json_object(depth : Int32, arrays : Int32, objects : Int32) : String
      return "null" if depth <= 0

      String.build do |str|
        str << "{\n"
        str << "  \"string_field\": \"test value #{Random.rand(1000)}\",\n"
        str << "  \"number_field\": #{Random.rand(1000)},\n"
        str << "  \"boolean_field\": #{Random.rand(2) == 1},\n"

        arrays.times do |i|
          str << "  \"array_#{i}\": ["
          5.times do |j|
            str << "\"item_#{j}\""
            str << ", " unless j == 4
          end
          str << "],\n"
        end

        if depth > 1
          objects.times do |i|
            str << "  \"nested_#{i}\": "
            str << generate_json_object(depth - 1, arrays // 2, objects // 2)
            str << ",\n" unless i == objects - 1
          end
        end

        str << "\n}"
      end
    end
  end
end
