require "../spec/spec_helper"

# AST Performance Benchmarking Suite
# This comprehensive suite measures baseline performance for various AST operations
# to establish metrics for optimization efforts.

# Sample AST definitions for benchmarking
include Hecate::AST

abstract_node Expr
abstract_node Stmt

node IntLit < Expr, value: Int32
node StringLit < Expr, value: String
node BoolLit < Expr, value: Bool
node Identifier < Expr, name: String

node BinaryOp < Expr, 
  left: Expr, 
  operator: String, 
  right: Expr

node Block < Stmt, statements: Array(Stmt)
node Assignment < Stmt, target: Identifier, value: Expr
node If < Stmt, condition: Expr, then_branch: Stmt, else_branch: Stmt?

finalize_ast(
  IntLit, StringLit, BoolLit, Identifier,
  BinaryOp, Block, Assignment, If
)

# Visitor for testing traversal performance
class CountingVisitor < Visitor(Int32)
  def initialize
    @count = 0
  end

  def visit_int_lit(node : IntLit) : Int32
    @count += 1
    @count
  end

  def visit_string_lit(node : StringLit) : Int32
    @count += 1
    @count
  end

  def visit_bool_lit(node : BoolLit) : Int32
    @count += 1
    @count
  end

  def visit_identifier(node : Identifier) : Int32
    @count += 1
    @count
  end

  def visit_binary_op(node : BinaryOp) : Int32
    visit(node.left)
    visit(node.right)
    @count += 1
    @count
  end

  def visit_block(node : Block) : Int32
    node.statements.each { |stmt| visit(stmt) }
    @count += 1
    @count
  end

  def visit_assignment(node : Assignment) : Int32
    visit(node.target)
    visit(node.value)
    @count += 1
    @count
  end

  def visit_if(node : If) : Int32
    visit(node.condition)
    visit(node.then_branch)
    node.else_branch.try { |branch| visit(branch) }
    @count += 1
    @count
  end

  def count
    @count
  end
end

# Transformer for testing transformation performance
class ConstantFoldingTransformer < Transformer
  def visit_binary_op(node : BinaryOp) : ::Hecate::AST::Node
    left = visit(node.left)
    right = visit(node.right)
    
    # Simple constant folding for integer addition
    if left.is_a?(IntLit) && right.is_a?(IntLit) && node.operator == "+"
      IntLit.new(node.span, left.value + right.value)
    else
      BinaryOp.new(node.span, left.as(Expr), node.operator, right.as(Expr))
    end
  end
end

describe "AST Performance Benchmarks" do
  # Helper method to create test spans
  private def span(start_byte = 0, end_byte = 0)
    Hecate::Core::Span.new(0_u32, start_byte, end_byte)
  end

  # Helper methods to create test AST nodes
  private def create_int_lit(value)
    IntLit.new(span, value)
  end

  private def create_binary_op(left, op, right)
    BinaryOp.new(span, left, op, right)
  end

  private def create_deep_binary_tree(depth : Int32) : Expr
    return create_int_lit(1) if depth == 0
    
    left = create_deep_binary_tree(depth - 1)
    right = create_deep_binary_tree(depth - 1)
    create_binary_op(left, "+", right)
  end

  private def create_wide_binary_tree(width : Int32) : Expr
    return create_int_lit(1) if width == 1
    
    nodes = (1..width).map { |i| create_int_lit(i) }.to_a
    
    # Chain them with binary operations
    result = nodes.first
    nodes[1..].each do |node|
      result = create_binary_op(result, "+", node)
    end
    
    result
  end

  describe "Node Creation Performance" do
    it "measures simple leaf node creation speed" do
      nodes_created = 0
      
      elapsed = Benchmark.measure do
        100_000.times do |i|
          IntLit.new(span, i)
          nodes_created += 1
        end
      end
      
      puts "\n=== Leaf Node Creation Performance ==="
      puts "Created #{nodes_created} IntLit nodes"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(nodes_created / elapsed.real).round(0)} nodes/sec"
      puts "Memory per node: ~#{(elapsed.real * 1000 / nodes_created).round(4)}ms"
    end

    it "measures complex node creation speed" do
      nodes_created = 0
      
      elapsed = Benchmark.measure do
        10_000.times do |i|
          left = create_int_lit(i)
          right = create_int_lit(i + 1)
          create_binary_op(left, "+", right)
          nodes_created += 3  # 1 binary op + 2 int lits
        end
      end
      
      puts "\n=== Complex Node Creation Performance ==="
      puts "Created #{nodes_created} total nodes (10K BinaryOp + 20K IntLit)"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(nodes_created / elapsed.real).round(0)} nodes/sec"
    end

    it "measures array-based node creation" do
      blocks_created = 0
      total_nodes = 0
      
      elapsed = Benchmark.measure do
        1_000.times do |i|
          statements = (1..10).map do |j|
            target = Identifier.new(span, "var#{j}")
            value = create_int_lit(j)
            Assignment.new(span, target, value)
          end.to_a.map(&.as(Stmt))
          
          Block.new(span, statements)
          blocks_created += 1
          total_nodes += 31  # 1 block + 10 assignments + 10 identifiers + 10 int lits
        end
      end
      
      puts "\n=== Array-based Node Creation Performance ==="
      puts "Created #{blocks_created} blocks with #{total_nodes} total nodes"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(total_nodes / elapsed.real).round(0)} nodes/sec"
    end
  end

  describe "Visitor Traversal Performance" do
    it "measures visitor traversal on deep trees" do
      tree_depth = 15
      tree = create_deep_binary_tree(tree_depth)
      visitor = CountingVisitor.new
      expected_nodes = (2 ** (tree_depth + 1)) - 1  # Binary tree node count
      
      elapsed = Benchmark.measure do
        100.times do
          visitor = CountingVisitor.new
          visitor.visit(tree)
        end
      end
      
      puts "\n=== Deep Tree Traversal Performance ==="
      puts "Tree depth: #{tree_depth} (#{expected_nodes} nodes)"
      puts "Traversals: 100"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(100 * expected_nodes / elapsed.real).round(0)} nodes/sec"
      puts "Time per traversal: #{(elapsed.real / 100 * 1000).round(2)}ms"
    end

    it "measures visitor traversal on wide trees" do
      tree_width = 1000
      tree = create_wide_binary_tree(tree_width)
      visitor = CountingVisitor.new
      expected_nodes = (tree_width * 2) - 1  # Chain of binary ops
      
      elapsed = Benchmark.measure do
        100.times do
          visitor = CountingVisitor.new
          visitor.visit(tree)
        end
      end
      
      puts "\n=== Wide Tree Traversal Performance ==="
      puts "Tree width: #{tree_width} (#{expected_nodes} nodes)"
      puts "Traversals: 100"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(100 * expected_nodes / elapsed.real).round(0)} nodes/sec"
      puts "Time per traversal: #{(elapsed.real / 100 * 1000).round(2)}ms"
    end
  end

  describe "AST Transformation Performance" do
    it "measures transformation performance" do
      # Create a tree with many opportunities for constant folding
      tree = (1..100).reduce(create_int_lit(0)) do |acc, i|
        create_binary_op(acc, "+", create_int_lit(i))
      end
      
      transformer = ConstantFoldingTransformer.new
      
      elapsed = Benchmark.measure do
        50.times do
          transformer.visit(tree)
        end
      end
      
      puts "\n=== AST Transformation Performance ==="
      puts "Tree size: ~200 nodes"
      puts "Transformations: 50"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(50 * 200 / elapsed.real).round(0)} nodes/sec"
      puts "Time per transformation: #{(elapsed.real / 50 * 1000).round(2)}ms"
    end
  end

  describe "Node Cloning Performance" do
    it "measures deep cloning performance" do
      tree_depth = 12
      tree = create_deep_binary_tree(tree_depth)
      expected_nodes = (2 ** (tree_depth + 1)) - 1
      
      elapsed = Benchmark.measure do
        100.times do
          tree.clone
        end
      end
      
      puts "\n=== Deep Cloning Performance ==="
      puts "Tree depth: #{tree_depth} (#{expected_nodes} nodes)"
      puts "Clones: 100"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(100 * expected_nodes / elapsed.real).round(0)} nodes/sec"
      puts "Time per clone: #{(elapsed.real / 100 * 1000).round(2)}ms"
    end
  end

  describe "Memory Usage Analysis" do
    it "estimates memory usage patterns" do
      # This is a rough estimation - in a real implementation, you'd use
      # Crystal's built-in memory profiler or external tools
      
      puts "\n=== Memory Usage Estimates ==="
      
      # Test small nodes
      small_nodes = [] of IntLit
      10_000.times { |i| small_nodes << create_int_lit(i) }
      
      puts "IntLit nodes: 10,000 created"
      puts "Estimated size: ~#{(10_000 * 32).round(0)} bytes (32 bytes/node estimate)"
      
      # Test complex nodes with arrays
      blocks = [] of Block
      100.times do |i|
        statements = (1..50).map do |j|
          Assignment.new(span, Identifier.new(span, "var#{j}"), create_int_lit(j))
        end.to_a.map(&.as(Stmt))
        blocks << Block.new(span, statements)
      end
      
      puts "Block nodes: 100 created (50 statements each)"
      puts "Total nodes: ~15,100 (100 blocks + 5,000 assignments + 5,000 identifiers + 5,000 int lits)"
      puts "Estimated size: ~#{(15_100 * 40).round(0)} bytes (40 bytes/node average estimate)"
    end
  end

  describe "Find Operations Performance" do
    it "measures find_all performance" do
      tree = create_deep_binary_tree(10)  # 2047 nodes
      
      elapsed = Benchmark.measure do
        500.times do
          tree.find_all(IntLit)
        end
      end
      
      int_lits_found = tree.find_all(IntLit).size
      
      puts "\n=== Find All Operations Performance ==="
      puts "Tree size: 2047 nodes"
      puts "IntLit nodes found: #{int_lits_found}"
      puts "Find operations: 500"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(500 * 2047 / elapsed.real).round(0)} nodes searched/sec"
    end

    it "measures children collection performance" do
      tree = create_deep_binary_tree(10)
      
      elapsed = Benchmark.measure do
        1000.times do
          collect_all_children(tree)
        end
      end
      
      puts "\n=== Children Collection Performance ==="
      puts "Tree size: 2047 nodes"
      puts "Collections: 1000"
      puts "Time: #{elapsed.real.round(4)}s"
      puts "Rate: #{(1000 * 2047 / elapsed.real).round(0)} nodes/sec"
    end
  end

  # Helper method to recursively collect all children
  private def collect_all_children(node : ::Hecate::AST::Node) : Array(::Hecate::AST::Node)
    result = [node]
    node.children.each do |child|
      result.concat(collect_all_children(child))
    end
    result
  end
end