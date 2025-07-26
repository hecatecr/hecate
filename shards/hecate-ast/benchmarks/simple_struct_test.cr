require "../spec/spec_helper"
require "benchmark"

# Simple test of struct node implementation without complex finalization
module SimpleStructTest
  include Hecate::AST

  abstract_node Expr

  # Use struct_node for memory optimization  
  struct_node IntLit < Expr, value : Int32

  # Compare with regular class node
  node BinaryOp < Expr, left : Expr, operator : String, right : Expr

  # Simple finalization - just create visitors without type predicates for now
  abstract class Visitor(T)
    abstract def visit_int_lit(node : IntLit) : T
    abstract def visit_binary_op(node : BinaryOp) : T
    
    def visit(node : ::Hecate::AST::Node) : T
      node.accept(self)
    end
  end
end

# Test visitor
class SimpleTestVisitor < SimpleStructTest::Visitor(String)
  def visit_int_lit(node : SimpleStructTest::IntLit) : String
    "IntLit(#{node.value})"
  end

  def visit_binary_op(node : SimpleStructTest::BinaryOp) : String
    left = visit(node.left)
    right = visit(node.right)
    "BinaryOp(#{left} #{node.operator} #{right})"
  end
end

def span(start_byte = 0, end_byte = 0)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

puts "🧪 SIMPLE STRUCT NODE TEST"
puts "=" * 40

# Test basic struct node functionality
int_struct = SimpleStructTest::IntLit.new(span, 42)
puts "✅ Struct IntLit created: #{int_struct}"
puts "  Value: #{int_struct.value}"
puts "  Span: #{int_struct.span}"
puts "  Is leaf: #{int_struct.leaf?}"
puts "  Children: #{int_struct.children}"
puts

# Test visitor with struct
visitor = SimpleTestVisitor.new
result = visitor.visit(int_struct)
puts "✅ Visitor works with struct: #{result}"
puts

# Test cloning
cloned = int_struct.clone
puts "✅ Cloning works: #{cloned}"
puts "  Equal to original: #{int_struct == cloned}"
puts

# Test memory usage comparison
puts "💾 MEMORY COMPARISON"
puts "-" * 25

GC.collect
sleep 0.01.seconds

# Test struct memory
before_struct = GC.stats
struct_array = [] of SimpleStructTest::IntLit
10_000.times { |i| struct_array << SimpleStructTest::IntLit.new(span, i) }
after_struct = GC.stats

struct_bytes = after_struct.total_bytes - before_struct.total_bytes
struct_per_node = struct_bytes / 10_000

puts "Struct IntLit nodes (10,000):"
puts "  Total memory: #{struct_bytes} bytes"
puts "  Per node: ~#{struct_per_node} bytes"

# Clear and test class memory
struct_array.clear
GC.collect
sleep 0.01.seconds

before_class = GC.stats
class_array = [] of SimpleStructTest::BinaryOp
5_000.times do |i|
  left = SimpleStructTest::IntLit.new(span, i)
  right = SimpleStructTest::IntLit.new(span, i + 1)  
  class_array << SimpleStructTest::BinaryOp.new(span, left, "+", right)
end
after_class = GC.stats

class_bytes = after_class.total_bytes - before_class.total_bytes
# Each iteration creates 3 nodes total: 1 BinaryOp + 2 IntLit
class_per_node = class_bytes / 15_000

puts "\nClass BinaryOp+IntLit nodes (15,000 total):"
puts "  Total memory: #{class_bytes} bytes"
puts "  Per node: ~#{class_per_node} bytes"

class_array.clear

# Compare performance
puts "\n⚡ PERFORMANCE COMPARISON"
puts "-" * 30

struct_time = Benchmark.measure do
  100_000.times { |i| SimpleStructTest::IntLit.new(span, i) }
end

struct_rate = 100_000 / struct_time.real

mixed_time = Benchmark.measure do
  10_000.times do |i|
    left = SimpleStructTest::IntLit.new(span, i) 
    right = SimpleStructTest::IntLit.new(span, i + 1)
    SimpleStructTest::BinaryOp.new(span, left, "+", right)
  end
end

mixed_rate = 30_000 / mixed_time.real

puts "Creation performance:"
puts "  Pure struct: #{struct_rate.round(0)} nodes/sec"
puts "  Mixed (struct+class): #{mixed_rate.round(0)} nodes/sec"

# Test visitor performance
pure_struct_visit_time = Benchmark.measure do
  node = SimpleStructTest::IntLit.new(span, 42)
  10_000.times { visitor.visit(node) }
end

mixed_visit_time = Benchmark.measure do
  left = SimpleStructTest::IntLit.new(span, 1)
  right = SimpleStructTest::IntLit.new(span, 2)
  tree = SimpleStructTest::BinaryOp.new(span, left, "+", right)
  5_000.times { visitor.visit(tree) }
end

pure_visit_rate = 10_000 / pure_struct_visit_time.real
mixed_visit_rate = 15_000 / mixed_visit_time.real

puts "\nVisitor performance:"
puts "  Pure struct: #{pure_visit_rate.round(0)} visits/sec"
puts "  Mixed tree: #{mixed_visit_rate.round(0)} nodes/sec"

puts "\n🎯 RESULTS SUMMARY"
puts "=" * 40

baseline_memory = 90
if struct_per_node < baseline_memory
  improvement = ((baseline_memory - struct_per_node) / baseline_memory * 100).round(1)
  puts "✅ Memory improvement: #{improvement}% reduction"
  puts "   Baseline: #{baseline_memory} bytes/node"
  puts "   Struct: #{struct_per_node} bytes/node"
  puts "   Savings: #{baseline_memory - struct_per_node} bytes/node"
else
  puts "❌ No memory improvement over baseline"
  puts "   Baseline: #{baseline_memory} bytes/node" 
  puts "   Struct: #{struct_per_node} bytes/node"
end

puts "\n✅ Performance results:"
puts "   Struct creation: #{struct_rate.round(0)} nodes/sec"
puts "   Struct visitor: #{pure_visit_rate.round(0)} visits/sec"
puts "   Mixed performance: #{mixed_rate.round(0)} nodes/sec"