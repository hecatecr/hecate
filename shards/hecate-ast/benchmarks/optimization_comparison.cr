require "../spec/spec_helper"
require "benchmark"

# Comprehensive comparison of all AST optimization approaches
module OptimizationComparison  
  include Hecate::AST

  abstract_node Expr

  # Regular unoptimized nodes (baseline)
  node RegularIntLit < Expr, value : Int32
  node RegularBoolLit < Expr, value : Bool
  node RegularStringLit < Expr, value : String
  node RegularIdentifier < Expr, name : String

  # Optimized nodes (layout optimizations)
  optimized_node OptimizedIntLit < Expr, value : Int32
  optimized_node OptimizedBoolLit < Expr, value : Bool
  optimized_node OptimizedStringLit < Expr, value : String
  optimized_node OptimizedIdentifier < Expr, name : String

  # Pooled nodes (optimized + object pooling)
  pooled_node PooledIntLit < Expr, value : Int32
  pooled_node PooledBoolLit < Expr, value : Bool
  pooled_node PooledStringLit < Expr, value : String
  pooled_node PooledIdentifier < Expr, name : String

  finalize_ast RegularIntLit, RegularBoolLit, RegularStringLit, RegularIdentifier,
               OptimizedIntLit, OptimizedBoolLit, OptimizedStringLit, OptimizedIdentifier,
               PooledIntLit, PooledBoolLit, PooledStringLit, PooledIdentifier
end

# Test visitor for all node types
class ComparisonVisitor < OptimizationComparison::Visitor(String)
  def visit_regular_int_lit(node) : String
    "RegularIntLit(#{node.value})"
  end

  def visit_regular_bool_lit(node) : String
    "RegularBoolLit(#{node.value})"
  end

  def visit_regular_string_lit(node) : String
    "RegularStringLit(#{node.value})"
  end

  def visit_regular_identifier(node) : String
    "RegularIdentifier(#{node.name})"
  end

  def visit_optimized_int_lit(node) : String
    "OptimizedIntLit(#{node.value})"
  end

  def visit_optimized_bool_lit(node) : String
    "OptimizedBoolLit(#{node.value})"
  end

  def visit_optimized_string_lit(node) : String
    "OptimizedStringLit(#{node.value})"
  end

  def visit_optimized_identifier(node) : String
    "OptimizedIdentifier(#{node.name})"
  end

  def visit_pooled_int_lit(node) : String
    "PooledIntLit(#{node.value})"
  end

  def visit_pooled_bool_lit(node) : String
    "PooledBoolLit(#{node.value})"
  end

  def visit_pooled_string_lit(node) : String
    "PooledStringLit(#{node.value})"
  end

  def visit_pooled_identifier(node) : String
    "PooledIdentifier(#{node.name})"
  end
end

def span(start_byte = 0, end_byte = 0)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

def measure_memory_usage(description : String, &block)
  GC.collect
  sleep 0.01.seconds
  
  before = GC.stats
  nodes = yield
  after = GC.stats
  
  bytes_used = after.total_bytes - before.total_bytes
  per_node = bytes_used / nodes.size
  
  puts "  #{description}:"
  puts "    Total: #{bytes_used} bytes"
  puts "    Per node: #{per_node} bytes"
  puts "    Node count: #{nodes.size}"
  
  nodes.clear  # Clear to avoid affecting subsequent measurements
  per_node
end

puts "🎯 COMPREHENSIVE AST OPTIMIZATION COMPARISON"
puts "=" * 70

# Clear any existing pools
::Hecate::AST::NodePool.clear_pools

puts "\n💾 MEMORY USAGE COMPARISON"
puts "-" * 50

# Test IntLit nodes
puts "\nIntLit Memory Usage (10,000 nodes):"

regular_int_memory = measure_memory_usage("Regular IntLit") do
  (1..10_000).map { |i| OptimizationComparison::RegularIntLit.new(span, i) }
end

optimized_int_memory = measure_memory_usage("Optimized IntLit") do
  (1..10_000).map { |i| OptimizationComparison::OptimizedIntLit.new(span, i) }
end

pooled_int_memory = measure_memory_usage("Pooled IntLit") do
  (1..10_000).map { |i| OptimizationComparison::PooledIntLit.new(span, i % 256) }  # Use values that will be pooled
end

puts "\nBoolLit Memory Usage (1,000 nodes):"

regular_bool_memory = measure_memory_usage("Regular BoolLit") do
  (1..1_000).map { |i| OptimizationComparison::RegularBoolLit.new(span, i % 2 == 0) }
end

optimized_bool_memory = measure_memory_usage("Optimized BoolLit") do
  (1..1_000).map { |i| OptimizationComparison::OptimizedBoolLit.new(span, i % 2 == 0) }
end

pooled_bool_memory = measure_memory_usage("Pooled BoolLit") do
  (1..1_000).map { |i| OptimizationComparison::PooledBoolLit.new(span, i % 2 == 0) }
end

puts "\n⚡ PERFORMANCE COMPARISON"
puts "-" * 50

visitor = ComparisonVisitor.new

# Node Creation Performance
puts "\nNode Creation Performance (100,000 IntLit nodes):"

regular_creation_time = Benchmark.measure do
  100_000.times { |i| OptimizationComparison::RegularIntLit.new(span, i) }
end

optimized_creation_time = Benchmark.measure do
  100_000.times { |i| OptimizationComparison::OptimizedIntLit.new(span, i) }
end

pooled_creation_time = Benchmark.measure do
  100_000.times { |i| OptimizationComparison::PooledIntLit.new(span, i % 256) }
end

regular_rate = 100_000 / regular_creation_time.real
optimized_rate = 100_000 / optimized_creation_time.real
pooled_rate = 100_000 / pooled_creation_time.real

puts "  Regular: #{regular_rate.round(0)} nodes/sec"
puts "  Optimized: #{optimized_rate.round(0)} nodes/sec (#{(optimized_rate/regular_rate).round(2)}x)"
puts "  Pooled: #{pooled_rate.round(0)} nodes/sec (#{(pooled_rate/regular_rate).round(2)}x)"

# Visitor Performance
puts "\nVisitor Performance (10,000 visits):"

regular_int = OptimizationComparison::RegularIntLit.new(span, 42)
optimized_int = OptimizationComparison::OptimizedIntLit.new(span, 42)
pooled_int = OptimizationComparison::PooledIntLit.new(span, 42)

regular_visit_time = Benchmark.measure do
  10_000.times { visitor.visit(regular_int) }
end

optimized_visit_time = Benchmark.measure do
  10_000.times { visitor.visit(optimized_int) }
end

pooled_visit_time = Benchmark.measure do
  10_000.times { visitor.visit(pooled_int) }
end

regular_visit_rate = 10_000 / regular_visit_time.real
optimized_visit_rate = 10_000 / optimized_visit_time.real
pooled_visit_rate = 10_000 / pooled_visit_time.real

puts "  Regular: #{regular_visit_rate.round(0)} visits/sec"
puts "  Optimized: #{optimized_visit_rate.round(0)} visits/sec (#{(optimized_visit_rate/regular_visit_rate).round(2)}x)"
puts "  Pooled: #{pooled_visit_rate.round(0)} visits/sec (#{(pooled_visit_rate/regular_visit_rate).round(2)}x)"

# Cloning Performance
puts "\nCloning Performance (10,000 clones):"

regular_clone_time = Benchmark.measure do
  10_000.times { regular_int.clone }
end

optimized_clone_time = Benchmark.measure do
  10_000.times { optimized_int.clone }
end

pooled_clone_time = Benchmark.measure do
  10_000.times { pooled_int.clone }
end

regular_clone_rate = 10_000 / regular_clone_time.real
optimized_clone_rate = 10_000 / optimized_clone_time.real
pooled_clone_rate = 10_000 / pooled_clone_time.real

puts "  Regular: #{regular_clone_rate.round(0)} clones/sec"
puts "  Optimized: #{optimized_clone_rate.round(0)} clones/sec (#{(optimized_clone_rate/regular_clone_rate).round(2)}x)"
puts "  Pooled: #{pooled_clone_rate.round(0)} clones/sec (#{(pooled_clone_rate/regular_clone_rate).round(2)}x)"

# Pool Statistics
puts "\n🏊 POOL STATISTICS"
puts "-" * 50

pool_stats = ::Hecate::AST::NodePool.pool_stats
pool_memory = ::Hecate::AST::NodePool.pool_memory_estimate

puts "Pool Hit Statistics:"
puts "  Total hits: #{pool_stats[:hits]}"
puts "  Total misses: #{pool_stats[:misses]}"
puts "  Hit rate: #{pool_stats[:hit_rate]}%"

puts "\nPool Sizes:"
puts "  Integer pool: #{pool_stats[:int_pool_size]} nodes"
puts "  Boolean pool: #{pool_stats[:bool_pool_size]} nodes"
puts "  String pool: #{pool_stats[:string_pool_size]} nodes"
puts "  Identifier pool: #{pool_stats[:identifier_pool_size]} nodes"

puts "\nPool Memory Usage:"
puts "  Integer pool: ~#{pool_memory[:int_pool_bytes]} bytes"
puts "  Boolean pool: ~#{pool_memory[:bool_pool_bytes]} bytes"
puts "  String pool: ~#{pool_memory[:string_pool_bytes]} bytes"
puts "  Identifier pool: ~#{pool_memory[:identifier_pool_bytes]} bytes"
puts "  Total pool memory: ~#{pool_memory[:total_bytes]} bytes"

puts "\n📊 RESULTS SUMMARY"
puts "=" * 70

baseline_memory = 90  # Original baseline from our first measurement
target_memory = 64

puts "Memory Results:"
puts "  Original baseline: #{baseline_memory} bytes/node"
puts "  Target: <#{target_memory} bytes/node"
puts "  Regular nodes: #{regular_int_memory.round(1)} bytes/node"
puts "  Optimized nodes: #{optimized_int_memory.round(1)} bytes/node"
puts "  Pooled nodes: #{pooled_int_memory.round(1)} bytes/node"

best_memory = [regular_int_memory, optimized_int_memory, pooled_int_memory].min
if best_memory < target_memory
  puts "  ✅ TARGET ACHIEVED: #{best_memory.round(1)} < #{target_memory} bytes/node"
  improvement = ((baseline_memory - best_memory) / baseline_memory * 100).round(1)
  puts "  🎉 #{improvement}% memory reduction vs baseline"
else
  puts "  ⚠️  Target not met: need #{(best_memory - target_memory).round(1)} more bytes reduction"
end

puts "\nPerformance Results:"
best_creation = [regular_rate, optimized_rate, pooled_rate].max
best_visit = [regular_visit_rate, optimized_visit_rate, pooled_visit_rate].max
best_clone = [regular_clone_rate, optimized_clone_rate, pooled_clone_rate].max

puts "  Best node creation: #{best_creation.round(0)} nodes/sec"
puts "  Best visitor performance: #{best_visit.round(0)} visits/sec"
puts "  Best cloning performance: #{best_clone.round(0)} clones/sec"

if pool_stats[:hit_rate] > 50
  puts "  ✅ Effective pooling: #{pool_stats[:hit_rate]}% hit rate"
else
  puts "  ⚠️  Low pooling effectiveness: #{pool_stats[:hit_rate]}% hit rate"
end

puts "\n🎯 OPTIMIZATION RECOMMENDATIONS"
puts "=" * 70

if optimized_int_memory < regular_int_memory
  puts "✅ Use optimized_node for better performance and memory"
else
  puts "⚠️  Regular nodes perform similarly to optimized"
end

if pooled_int_memory < optimized_int_memory && pool_stats[:hit_rate] > 30
  puts "✅ Use pooled_node for applications with repeated literal values"
else
  puts "⚠️  Pooling not effective for this usage pattern"
end

if best_creation > 40_000_000
  puts "✅ Node creation performance is excellent (>40M nodes/sec)"
else
  puts "⚠️  Node creation could be improved"
end

if best_memory < target_memory
  puts "✅ Memory target achieved - optimization successful!"
else
  puts "🔄 Consider additional optimizations for memory usage"
end