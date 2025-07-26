require "../spec/spec_helper"
require "./memory_profiler"

# Comprehensive AST Performance Report Generator
# Generates detailed baseline metrics for optimization comparison

# Performance test AST module
module PerfTestAST
  include Hecate::AST

  # Define the same test AST structure
  abstract_node Expr
  abstract_node Stmt

  node IntLit < Expr, value : Int32
  node StringLit < Expr, value : String  
  node BoolLit < Expr, value : Bool
  node Identifier < Expr, name : String

  node BinaryOp < Expr, 
    left : Expr, 
    operator : String, 
    right : Expr

  node Block < Stmt, statements : Array(Stmt)
  node Assignment < Stmt, target : Identifier, value : Expr
  node If < Stmt, condition : Expr, then_branch : Stmt, else_branch : Stmt?

  finalize_ast IntLit, StringLit, BoolLit, Identifier, BinaryOp, Block, Assignment, If
end

class PerformanceReporter  
  include AST::MemoryProfiler
  
  def initialize
    @results = {} of String => Hash(String, Float64 | Int64 | String)
  end
  
  def span(start_byte = 0, end_byte = 0)
    Hecate::Core::Span.new(0_u32, start_byte, end_byte)
  end
  
  def run_full_report
    puts "=" * 80
    puts "AST PERFORMANCE BASELINE REPORT"
    puts "Generated: #{Time.local}"
    puts "Crystal Version: #{Crystal::VERSION}"
    puts "=" * 80
    puts
    
    measure_node_creation_performance
    measure_memory_usage_patterns  
    measure_visitor_performance
    measure_transformation_performance
    measure_cloning_performance
    measure_search_performance
    
    generate_summary
    save_results_to_file
  end
  
  private def measure_node_creation_performance
    puts "📊 NODE CREATION PERFORMANCE"
    puts "-" * 40
    
    # Simple leaf nodes
    leaf_time = Benchmark.measure do
      100_000.times { |i| PerfTestAST::IntLit.new(span, i) }
    end
    
    leaf_rate = 100_000 / leaf_time.real
    @results["leaf_creation"] = {
      "nodes_per_second" => leaf_rate,
      "time_per_node_ns" => (leaf_time.real * 1_000_000_000 / 100_000),
      "total_time_ms" => leaf_time.real * 1000
    }
    
    puts "  Leaf nodes (IntLit): #{leaf_rate.round(0)} nodes/sec"
    puts "  Time per node: #{(leaf_time.real * 1_000_000_000 / 100_000).round(2)}ns"
    
    # Complex nodes with child references
    complex_time = Benchmark.measure do
      10_000.times do |i|
        left = PerfTestAST::IntLit.new(span, i)
        right = PerfTestAST::IntLit.new(span, i + 1)
        PerfTestAST::BinaryOp.new(span, left, "+", right)
      end
    end
    
    complex_rate = 30_000 / complex_time.real  # 3 nodes per iteration
    @results["complex_creation"] = {
      "nodes_per_second" => complex_rate,
      "time_per_node_ns" => (complex_time.real * 1_000_000_000 / 30_000),
      "total_time_ms" => complex_time.real * 1000
    }
    
    puts "  Complex nodes (BinaryOp+children): #{complex_rate.round(0)} nodes/sec"
    puts "  Time per node: #{(complex_time.real * 1_000_000_000 / 30_000).round(2)}ns"
    
    # Array-heavy nodes
    array_time = Benchmark.measure do
      1_000.times do |i|
        statements = (1..20).map do |j|
          Assignment.new(span, Identifier.new(span, "var#{j}"), IntLit.new(span, j))
        end.to_a.map(&.as(Stmt))
        Block.new(span, statements)
      end
    end
    
    array_rate = 61_000 / array_time.real  # 61 nodes per iteration (1 + 20*3)
    @results["array_creation"] = {
      "nodes_per_second" => array_rate,
      "time_per_node_ns" => (array_time.real * 1_000_000_000 / 61_000),
      "total_time_ms" => array_time.real * 1000
    }
    
    puts "  Array-heavy nodes (Block): #{array_rate.round(0)} nodes/sec"
    puts "  Time per node: #{(array_time.real * 1_000_000_000 / 61_000).round(2)}ns"
    puts
  end
  
  private def measure_memory_usage_patterns
    puts "💾 MEMORY USAGE PATTERNS"
    puts "-" * 40
    
    # Single node size estimation
    int_lit_size = estimate_object_size(10_000) { IntLit.new(span, 42) }
    puts "  IntLit size: ~#{int_lit_size[:estimated_per_object]} bytes/node"
    @results["intlit_memory"] = {
      "bytes_per_node" => int_lit_size[:estimated_per_object],
      "total_allocated" => int_lit_size[:total_allocated]
    }
    
    binary_op_size = estimate_object_size(5_000) do
      left = IntLit.new(span, 1)
      right = IntLit.new(span, 2)
      BinaryOp.new(span, left, "+", right)
    end
    puts "  BinaryOp size: ~#{binary_op_size[:estimated_per_object]} bytes/node"
    @results["binaryop_memory"] = {
      "bytes_per_node" => binary_op_size[:estimated_per_object],
      "total_allocated" => binary_op_size[:total_allocated]
    }
    
    # Memory growth with tree depth
    depths = [5, 8, 10, 12]
    depths.each do |depth|
      tree = create_deep_binary_tree(depth)
      tree_profile = profile_ast_creation(1) { |i| tree }
      
      node_count = (2 ** (depth + 1)) - 1
      bytes_per_node = tree_profile[:allocated].used_bytes_diff / node_count
      
      puts "  Tree depth #{depth} (#{node_count} nodes): #{bytes_per_node} bytes/node"
      @results["tree_depth_#{depth}"] = {
        "node_count" => node_count,
        "total_bytes" => tree_profile[:allocated].used_bytes_diff,
        "bytes_per_node" => bytes_per_node
      }
    end
    puts
  end
  
  private def measure_visitor_performance
    puts "🚶 VISITOR PATTERN PERFORMANCE"
    puts "-" * 40
    
    tree = create_deep_binary_tree(12)  # 8191 nodes
    node_count = (2 ** 13) - 1
    
    visitor_time = Benchmark.measure do
      100.times do
        visitor = CountingVisitor.new
        visitor.visit(tree)
      end
    end
    
    visit_rate = (100 * node_count) / visitor_time.real
    @results["visitor_traversal"] = {
      "nodes_per_second" => visit_rate,
      "time_per_traversal_ms" => (visitor_time.real / 100 * 1000),
      "tree_size" => node_count
    }
    
    puts "  Traversal rate: #{visit_rate.round(0)} nodes/sec"
    puts "  Time per traversal: #{(visitor_time.real / 100 * 1000).round(2)}ms"
    puts "  Tree size: #{node_count} nodes"
    puts
  end
  
  private def measure_transformation_performance
    puts "🔄 TRANSFORMATION PERFORMANCE"
    puts "-" * 40
    
    # Create a tree with transformation opportunities
    tree = (1..50).reduce(IntLit.new(span, 0)) do |acc, i|
      BinaryOp.new(span, acc, "+", IntLit.new(span, i))
    end
    
    transformer = ConstantFoldingTransformer.new
    
    transform_time = Benchmark.measure do
      100.times do
        transformer.visit(tree)
      end
    end
    
    node_count = 99  # 50 binary ops + 49 int lits  
    transform_rate = (100 * node_count) / transform_time.real
    @results["transformation"] = {
      "nodes_per_second" => transform_rate,
      "time_per_transform_ms" => (transform_time.real / 100 * 1000),
      "tree_size" => node_count
    }
    
    puts "  Transform rate: #{transform_rate.round(0)} nodes/sec"
    puts "  Time per transform: #{(transform_time.real / 100 * 1000).round(2)}ms"
    puts "  Tree size: #{node_count} nodes"
    puts
  end
  
  private def measure_cloning_performance
    puts "📋 CLONING PERFORMANCE"
    puts "-" * 40
    
    tree = create_deep_binary_tree(10)  # 2047 nodes
    node_count = (2 ** 11) - 1
    
    clone_time = Benchmark.measure do
      100.times do
        tree.clone
      end
    end
    
    clone_rate = (100 * node_count) / clone_time.real
    @results["cloning"] = {
      "nodes_per_second" => clone_rate,
      "time_per_clone_ms" => (clone_time.real / 100 * 1000),
      "tree_size" => node_count
    }
    
    puts "  Clone rate: #{clone_rate.round(0)} nodes/sec"
    puts "  Time per clone: #{(clone_time.real / 100 * 1000).round(2)}ms"
    puts "  Tree size: #{node_count} nodes"
    puts
  end
  
  private def measure_search_performance  
    puts "🔍 SEARCH PERFORMANCE"
    puts "-" * 40
    
    tree = create_deep_binary_tree(10)  # 2047 nodes
    node_count = (2 ** 11) - 1
    
    # find_all performance
    find_all_time = Benchmark.measure do
      200.times do
        tree.find_all(IntLit)
      end
    end
    
    find_all_rate = (200 * node_count) / find_all_time.real
    int_lits_found = tree.find_all(IntLit).size
    @results["find_all"] = {
      "nodes_per_second" => find_all_rate,
      "time_per_search_ms" => (find_all_time.real / 200 * 1000),
      "tree_size" => node_count,
      "results_found" => int_lits_found
    }
    
    puts "  find_all rate: #{find_all_rate.round(0)} nodes/sec"
    puts "  Time per search: #{(find_all_time.real / 200 * 1000).round(2)}ms"
    puts "  IntLit nodes found: #{int_lits_found}/#{node_count}"
    
    # find_first performance
    find_first_time = Benchmark.measure do
      10_000.times do
        tree.find_first(IntLit)
      end
    end
    
    find_first_rate = 10_000 / find_first_time.real
    @results["find_first"] = {
      "searches_per_second" => find_first_rate,
      "time_per_search_us" => (find_first_time.real / 10_000 * 1_000_000)
    }
    
    puts "  find_first rate: #{find_first_rate.round(0)} searches/sec"
    puts "  Time per search: #{(find_first_time.real / 10_000 * 1_000_000).round(2)}μs"
    puts
  end
  
  private def generate_summary
    puts "📈 PERFORMANCE SUMMARY"
    puts "-" * 40
    
    puts "  Node Creation (fastest to slowest):"
    leaf_rate = @results["leaf_creation"]["nodes_per_second"].as(Float64)
    complex_rate = @results["complex_creation"]["nodes_per_second"].as(Float64)
    array_rate = @results["array_creation"]["nodes_per_second"].as(Float64)
    
    rates = [
      {"Leaf nodes", leaf_rate},
      {"Complex nodes", complex_rate}, 
      {"Array-heavy nodes", array_rate}
    ].sort_by { |_, rate| -rate }
    
    rates.each_with_index do |(name, rate), i|
      puts "    #{i+1}. #{name}: #{rate.round(0)} nodes/sec"
    end
    
    puts "\n  Memory Efficiency:"
    intlit_bytes = @results["intlit_memory"]["bytes_per_node"].as(Int64)
    binaryop_bytes = @results["binaryop_memory"]["bytes_per_node"].as(Int64)
    
    puts "    IntLit: #{intlit_bytes} bytes/node"
    puts "    BinaryOp: #{binaryop_bytes} bytes/node"
    puts "    Overhead ratio: #{(binaryop_bytes.to_f / intlit_bytes).round(2)}x"
    
    puts "\n  Operation Performance:"
    visitor_rate = @results["visitor_traversal"]["nodes_per_second"].as(Float64)
    clone_rate = @results["cloning"]["nodes_per_second"].as(Float64)
    transform_rate = @results["transformation"]["nodes_per_second"].as(Float64)
    
    puts "    Visitor traversal: #{visitor_rate.round(0)} nodes/sec"
    puts "    AST cloning: #{clone_rate.round(0)} nodes/sec"
    puts "    Transformation: #{transform_rate.round(0)} nodes/sec"
    puts
  end
  
  private def save_results_to_file
    timestamp = Time.local.to_s("%Y%m%d_%H%M%S")
    filename = "ast_performance_baseline_#{timestamp}.json"
    
    File.open(filename, "w") do |file|
      @results.to_json(file)
    end
    
    puts "📄 Results saved to: #{filename}"
    puts "   Use this file to compare against future optimizations"
    puts
  end
  
  # Helper methods
  private def create_deep_binary_tree(depth : Int32) : Expr
    return IntLit.new(span, 1) if depth == 0
    
    left = create_deep_binary_tree(depth - 1)
    right = create_deep_binary_tree(depth - 1)
    BinaryOp.new(span, left, "+", right)
  end
  
  # Test visitor for counting nodes
  private class CountingVisitor < Visitor(Int32)
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
  
  # Test transformer for performance measurement
  private class ConstantFoldingTransformer < Transformer
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
end

# Run the performance report if this file is executed directly
if PROGRAM_NAME.includes?("performance_report")
  reporter = PerformanceReporter.new
  reporter.run_full_report
end