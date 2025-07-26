#!/usr/bin/env crystal

require "../spec/spec_helper"
require "benchmark"

# Simple baseline performance measurement
# This establishes basic performance metrics for AST operations

# Test AST module for baseline measurements
module BaselineAST
  include Hecate::AST

  abstract_node Expr
  abstract_node Stmt

  node IntLit < Expr, value : Int32
  node BinaryOp < Expr, left : Expr, operator : String, right : Expr
  node Block < Stmt, statements : Array(Stmt)
  node Assignment < Stmt, target : String, value : Expr

  finalize_ast IntLit, BinaryOp, Block, Assignment
end

# Test visitor for traversal benchmarks
class BaselineCountingVisitor < BaselineAST::Visitor(Int32)
  def initialize
    @count = 0
  end

  def visit_int_lit(node : BaselineAST::IntLit) : Int32
    @count += 1
    @count
  end

  def visit_binary_op(node : BaselineAST::BinaryOp) : Int32
    visit(node.left)
    visit(node.right)
    @count += 1
    @count
  end

  def visit_block(node : BaselineAST::Block) : Int32
    node.statements.each { |stmt| visit(stmt) }
    @count += 1
    @count
  end

  def visit_assignment(node : BaselineAST::Assignment) : Int32
    visit(node.value)
    @count += 1
    @count
  end

  def count
    @count
  end
end

# Helper method to create test spans
def span(start_byte = 0, end_byte = 0)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Create a binary tree of given depth
def create_binary_tree(depth : Int32) : BaselineAST::Expr
  return BaselineAST::IntLit.new(span, 1) if depth == 0
  
  left = create_binary_tree(depth - 1)
  right = create_binary_tree(depth - 1)
  BaselineAST::BinaryOp.new(span, left, "+", right)
end

puts "=" * 60
puts "AST PERFORMANCE BASELINE MEASUREMENTS"
puts "=" * 60
puts

# 1. Node Creation Performance
puts "📊 NODE CREATION PERFORMANCE"
puts "-" * 30

leaf_nodes = 0
leaf_time = Benchmark.measure do
  100_000.times do |i|
    BaselineAST::IntLit.new(span, i)
    leaf_nodes += 1
  end
end

puts "Leaf nodes (IntLit):"
puts "  Created: #{leaf_nodes} nodes"
puts "  Time: #{leaf_time.real.round(4)}s"
puts "  Rate: #{(leaf_nodes / leaf_time.real).round(0)} nodes/sec"
puts

complex_nodes = 0
complex_time = Benchmark.measure do
  10_000.times do |i|
    left = BaselineAST::IntLit.new(span, i)
    right = BaselineAST::IntLit.new(span, i + 1)
    BaselineAST::BinaryOp.new(span, left, "+", right)
    complex_nodes += 3  # 1 binary + 2 int lits
  end
end

puts "Complex nodes (BinaryOp + children):"
puts "  Created: #{complex_nodes} nodes"
puts "  Time: #{complex_time.real.round(4)}s"
puts "  Rate: #{(complex_nodes / complex_time.real).round(0)} nodes/sec"
puts

# 2. Visitor Pattern Performance
puts "🚶 VISITOR TRAVERSAL PERFORMANCE"
puts "-" * 30

tree = create_binary_tree(12)  # 8191 nodes
node_count = (2 ** 13) - 1

traversals = 0
visitor_time = Benchmark.measure do
  100.times do
    visitor = BaselineCountingVisitor.new
    visitor.visit(tree)
    traversals += 1
  end
end

puts "Deep tree traversal:"
puts "  Tree size: #{node_count} nodes"
puts "  Traversals: #{traversals}"
puts "  Time: #{visitor_time.real.round(4)}s"
puts "  Rate: #{(traversals * node_count / visitor_time.real).round(0)} nodes/sec"
puts "  Time per traversal: #{(visitor_time.real / traversals * 1000).round(2)}ms"
puts

# 3. Cloning Performance
puts "📋 CLONING PERFORMANCE"
puts "-" * 30

clones = 0
clone_time = Benchmark.measure do
  100.times do
    tree.clone
    clones += 1
  end
end

puts "Deep tree cloning:"
puts "  Tree size: #{node_count} nodes"
puts "  Clones: #{clones}"
puts "  Time: #{clone_time.real.round(4)}s"
puts "  Rate: #{(clones * node_count / clone_time.real).round(0)} nodes/sec"
puts "  Time per clone: #{(clone_time.real / clones * 1000).round(2)}ms"
puts

# 4. Search Performance
puts "🔍 SEARCH PERFORMANCE"
puts "-" * 30

searches = 0
search_time = Benchmark.measure do
  200.times do
    tree.find_all(BaselineAST::IntLit)
    searches += 1
  end
end

int_lits_found = tree.find_all(BaselineAST::IntLit).size

puts "find_all operations:"
puts "  Tree size: #{node_count} nodes"
puts "  Searches: #{searches}"
puts "  IntLit nodes found: #{int_lits_found}/#{node_count}"
puts "  Time: #{search_time.real.round(4)}s"
puts "  Rate: #{(searches * node_count / search_time.real).round(0)} nodes/sec"
puts "  Time per search: #{(search_time.real / searches * 1000).round(2)}ms"
puts

# 5. Memory Usage Estimation
puts "💾 MEMORY USAGE ESTIMATION"
puts "-" * 30

# Force GC to get clean measurements
GC.collect
sleep 0.01.seconds

before_stats = GC.stats

# Create many nodes to estimate memory usage
test_nodes = [] of BaselineAST::IntLit
10_000.times { |i| test_nodes << BaselineAST::IntLit.new(span, i) }

after_stats = GC.stats
bytes_used = after_stats.total_bytes - before_stats.total_bytes
estimated_per_node = bytes_used / 10_000

puts "Memory estimation (10,000 IntLit nodes):"
puts "  Total allocated: #{bytes_used} bytes"
puts "  Estimated per node: ~#{estimated_per_node} bytes"
puts "  Memory efficiency: #{(estimated_per_node < 100 ? "Good" : "Needs optimization")}"
puts

# Clear test nodes
test_nodes.clear

puts "=" * 60
puts "BASELINE SUMMARY"
puts "=" * 60
puts "✅ Node creation: #{(leaf_nodes / leaf_time.real).round(0)} simple nodes/sec"
puts "✅ Tree traversal: #{(traversals * node_count / visitor_time.real).round(0)} nodes/sec"
puts "✅ Tree cloning: #{(clones * node_count / clone_time.real).round(0)} nodes/sec"
puts "✅ Tree searching: #{(searches * node_count / search_time.real).round(0)} nodes/sec"
puts "✅ Memory usage: ~#{estimated_per_node} bytes/node"
puts
puts "🎯 OPTIMIZATION TARGETS:"
puts "   • Node creation: Target >1M nodes/sec"
puts "   • Visitor dispatch: Target >10M nodes/sec"  
puts "   • Memory usage: Target <64 bytes/node"
puts "   • Search operations: Target >5M nodes/sec"
puts

# Save baseline to file for comparison
timestamp = Time.local.to_s("%Y%m%d_%H%M%S")
filename = "ast_baseline_#{timestamp}.txt"

File.open(filename, "w") do |file|
  file.puts "AST Performance Baseline - #{Time.local}"
  file.puts "=" * 50
  file.puts "Node creation: #{(leaf_nodes / leaf_time.real).round(0)} nodes/sec"
  file.puts "Tree traversal: #{(traversals * node_count / visitor_time.real).round(0)} nodes/sec"
  file.puts "Tree cloning: #{(clones * node_count / clone_time.real).round(0)} nodes/sec"
  file.puts "Tree searching: #{(searches * node_count / search_time.real).round(0)} nodes/sec"
  file.puts "Memory per node: #{estimated_per_node} bytes"
end

puts "📄 Baseline saved to: #{filename}"