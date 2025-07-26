require "benchmark"
require "../src/hecate-ast"

# Mock node for benchmarking
class BenchNode < Hecate::AST::Node
  getter name : String
  getter child_nodes : Array(Hecate::AST::Node)

  def initialize(@name : String, child_nodes = [] of Hecate::AST::Node)
    @child_nodes = child_nodes.map(&.as(Hecate::AST::Node))
    super(Hecate::Core::Span.new(0_u32, 0, 0))
  end

  def children : Array(Hecate::AST::Node)
    @child_nodes
  end

  def accept(visitor)
    # Mock implementation
  end

  def clone : self
    BenchNode.new(@name, @child_nodes.map(&.clone))
  end
end

# Create benchmark trees of different sizes and shapes
def create_balanced_tree(depth : Int32, branching_factor : Int32) : BenchNode
  return BenchNode.new("leaf") if depth == 0

  children = (1..branching_factor).map do |i|
    create_balanced_tree(depth - 1, branching_factor).as(Hecate::AST::Node)
  end

  BenchNode.new("internal", children)
end

def create_linear_chain(length : Int32) : BenchNode
  return BenchNode.new("leaf") if length == 1

  child = create_linear_chain(length - 1)
  BenchNode.new("node#{length}", [child.as(Hecate::AST::Node)])
end

def create_wide_tree(width : Int32) : BenchNode
  children = (1..width).map { |i| BenchNode.new("child#{i}").as(Hecate::AST::Node) }
  BenchNode.new("root", children)
end

# Performance targets and measurements
puts "=== AST Traversal Performance Benchmarks ==="
puts

# Small balanced tree (depth 5, branching factor 3) = ~364 nodes
small_tree = create_balanced_tree(5, 3)
small_node_count = 0
Hecate::AST::TreeWalk.preorder(small_tree) { |_| small_node_count += 1 }

puts "Small balanced tree: #{small_node_count} nodes"
Benchmark.bm do |x|
  x.report("preorder") do
    1000.times do
      Hecate::AST::TreeWalk.preorder(small_tree) { |_| }
    end
  end

  x.report("postorder") do
    1000.times do
      Hecate::AST::TreeWalk.postorder(small_tree) { |_| }
    end
  end

  x.report("level_order") do
    1000.times do
      Hecate::AST::TreeWalk.level_order(small_tree) { |_| }
    end
  end

  x.report("with_depth") do
    1000.times do
      Hecate::AST::TreeWalk.with_depth(small_tree) { |_, _| }
    end
  end

  x.report("find_all") do
    1000.times do
      Hecate::AST::TreeWalk.find_all(small_tree, BenchNode)
    end
  end
end

puts

# Medium balanced tree (depth 7, branching factor 2) = ~255 nodes
medium_tree = create_balanced_tree(7, 2)
medium_node_count = 0
Hecate::AST::TreeWalk.preorder(medium_tree) { |_| medium_node_count += 1 }

puts "Medium balanced tree: #{medium_node_count} nodes"
Benchmark.bm do |x|
  x.report("preorder") do
    500.times do
      Hecate::AST::TreeWalk.preorder(medium_tree) { |_| }
    end
  end

  x.report("postorder") do
    500.times do
      Hecate::AST::TreeWalk.postorder(medium_tree) { |_| }
    end
  end

  x.report("level_order") do
    500.times do
      Hecate::AST::TreeWalk.level_order(medium_tree) { |_| }
    end
  end

  x.report("with_depth") do
    500.times do
      Hecate::AST::TreeWalk.with_depth(medium_tree) { |_, _| }
    end
  end

  x.report("find_all") do
    500.times do
      Hecate::AST::TreeWalk.find_all(medium_tree, BenchNode)
    end
  end
end

puts

# Linear chain (1000 nodes deep)
chain_tree = create_linear_chain(1000)

puts "Linear chain: 1000 nodes"
Benchmark.bm do |x|
  x.report("preorder") do
    100.times do
      Hecate::AST::TreeWalk.preorder(chain_tree) { |_| }
    end
  end

  x.report("postorder") do
    100.times do
      Hecate::AST::TreeWalk.postorder(chain_tree) { |_| }
    end
  end

  x.report("level_order") do
    100.times do
      Hecate::AST::TreeWalk.level_order(chain_tree) { |_| }
    end
  end

  x.report("with_depth") do
    100.times do
      Hecate::AST::TreeWalk.with_depth(chain_tree) { |_, _| }
    end
  end
end

puts

# Wide tree (1000 children)
wide_tree = create_wide_tree(1000)

puts "Wide tree: 1001 nodes (1 root + 1000 children)"
Benchmark.bm do |x|
  x.report("preorder") do
    100.times do
      Hecate::AST::TreeWalk.preorder(wide_tree) { |_| }
    end
  end

  x.report("postorder") do
    100.times do
      Hecate::AST::TreeWalk.postorder(wide_tree) { |_| }
    end
  end

  x.report("level_order") do
    100.times do
      Hecate::AST::TreeWalk.level_order(wide_tree) { |_| }
    end
  end

  x.report("with_depth") do
    100.times do
      Hecate::AST::TreeWalk.with_depth(wide_tree) { |_, _| }
    end
  end
end

puts
puts "=== Performance Analysis ==="
puts "Target: 100k+ nodes/second traversal speed"
puts "All methods should handle trees with 1000+ nodes efficiently"
puts "Memory usage should remain reasonable for deep recursion"
