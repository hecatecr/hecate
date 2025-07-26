require "../spec/spec_helper"

# Memory Profiling Utilities for AST Performance Analysis
# Provides tools to measure memory allocation patterns and usage

module AST::MemoryProfiler
  extend self

  # Simple memory measurement using GC stats
  # Note: This provides rough estimates - for precise measurements,
  # use external profiling tools like valgrind or heaptrack
  
  struct MemorySnapshot
    getter heap_size : UInt64
    getter total_bytes : UInt64
    getter free_bytes : UInt64
    
    def initialize
      stats = GC.stats
      @heap_size = stats.heap_size
      @total_bytes = stats.total_bytes  
      @free_bytes = stats.free_bytes
    end
    
    def used_bytes
      @total_bytes - @free_bytes
    end
    
    def -(other : MemorySnapshot) : MemoryDiff
      MemoryDiff.new(
        heap_size: @heap_size - other.heap_size,
        total_bytes: @total_bytes - other.total_bytes,
        free_bytes: @free_bytes - other.free_bytes
      )
    end
  end
  
  struct MemoryDiff
    getter heap_size : Int64
    getter total_bytes : Int64
    getter free_bytes : Int64
    
    def initialize(@heap_size : Int64, @total_bytes : Int64, @free_bytes : Int64)
    end
    
    def used_bytes_diff
      @total_bytes - @free_bytes
    end
    
    def to_s(io : IO)
      io << "MemoryDiff("
      io << "heap: " << format_bytes(@heap_size) << ", "
      io << "total: " << format_bytes(@total_bytes) << ", "
      io << "used: " << format_bytes(used_bytes_diff)
      io << ")"
    end
    
    private def format_bytes(bytes : Int64) : String
      case bytes.abs
      when 0...1024
        "#{bytes}B"
      when 1024...1024*1024
        "#{(bytes / 1024.0).round(1)}KB"
      when 1024*1024...1024*1024*1024
        "#{(bytes / (1024.0 * 1024)).round(1)}MB"
      else
        "#{(bytes / (1024.0 * 1024 * 1024)).round(1)}GB"
      end
    end
  end
  
  # Profile memory usage of a block of code
  def profile(&block)
    # Force GC to get a clean baseline
    GC.collect
    sleep 0.01  # Let GC settle
    
    before = MemorySnapshot.new
    result = yield
    after = MemorySnapshot.new
    
    # Force GC again to see what was actually retained
    GC.collect
    sleep 0.01
    final = MemorySnapshot.new
    
    {
      result: result,
      allocated: after - before,
      retained: final - before
    }
  end
  
  # Profile a block multiple times and return statistics
  def profile_multiple(iterations : Int32, &block)
    results = [] of MemoryDiff
    allocated_total = [] of Int64
    retained_total = [] of Int64
    
    iterations.times do
      profile_result = profile { yield }
      results << profile_result[:allocated]
      allocated_total << profile_result[:allocated].used_bytes_diff
      retained_total << profile_result[:retained].used_bytes_diff
    end
    
    {
      iterations: iterations,
      allocated_avg: allocated_total.sum / iterations,
      allocated_min: allocated_total.min,
      allocated_max: allocated_total.max,
      retained_avg: retained_total.sum / iterations,
      retained_min: retained_total.min,
      retained_max: retained_total.max
    }
  end
  
  # Estimate object size by creating many instances
  def estimate_object_size(count : Int32 = 10_000, &block)
    GC.collect
    before = MemorySnapshot.new
    
    objects = [] of typeof(yield)
    count.times { objects << yield }
    
    after = MemorySnapshot.new
    diff = after - before
    
    # Keep objects alive to prevent GC
    objects.clear
    
    {
      total_allocated: diff.used_bytes_diff,
      estimated_per_object: diff.used_bytes_diff / count,
      count: count
    }
  end
  
  # Profile AST-specific patterns
  def profile_ast_creation(node_count : Int32, &block : Int32 -> ::Hecate::AST::Node)
    profile do
      nodes = [] of ::Hecate::AST::Node
      node_count.times { |i| nodes << yield(i) }
      nodes
    end
  end
  
  def profile_ast_traversal(tree : ::Hecate::AST::Node, visitor, iterations : Int32 = 100)
    profile do
      iterations.times do
        visitor.visit(tree)
      end
    end
  end
  
  def profile_ast_cloning(tree : ::Hecate::AST::Node, iterations : Int32 = 100)
    profile do
      iterations.times do
        tree.clone
      end
    end
  end
  
  # Simple visitor for traversal profiling - will be defined in the using context
end