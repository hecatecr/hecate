require "../src/hecate-ast"

# Define a simple expression language AST
module SimpleAST
  include Hecate::AST
  
  # Define abstract base types
  abstract_node Expr
  abstract_node Stmt
  
  # Literal expressions
  node IntLit < Expr, value: Int32
  node StringLit < Expr, value: String
  node BoolLit < Expr, value: Bool
  
  # Binary expressions
  node Add < Expr, left: Expr, right: Expr
  node Subtract < Expr, left: Expr, right: Expr
  node Multiply < Expr, left: Expr, right: Expr
  node Divide < Expr, left: Expr, right: Expr
  
  # Comparison expressions
  node Equal < Expr, left: Expr, right: Expr
  node LessThan < Expr, left: Expr, right: Expr
  
  # Statements
  node VarDecl < Stmt, name: String, value: Expr?
  node Assignment < Stmt, name: String, value: Expr
  node Block < Stmt, statements: Array(Stmt)
  node If < Stmt, condition: Expr, then_stmt: Stmt, else_stmt: Stmt?
  node While < Stmt, condition: Expr, body: Stmt
  node ExprStmt < Stmt, expr: Expr
end

# Helper to create spans
def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Example usage
include SimpleAST

# Create an AST for: x = 1 + 2
ast = Assignment.new(
  "x",
  Add.new(
    IntLit.new(1, make_span(4, 5)),
    IntLit.new(2, make_span(8, 9)),
    make_span(4, 9)
  ),
  make_span(0, 9)
)

puts "Created AST:"
puts "  Type: #{ast.class}"
puts "  Variable: #{ast.name}"
puts "  Value type: #{ast.value.class}"
puts "  Children count: #{ast.children.size}"

# Clone the AST
cloned = ast.clone
puts "\nCloned AST:"
puts "  Equal to original? #{ast == cloned}"
puts "  Same object? #{ast.same?(cloned)}"

# Traverse the tree
puts "\nTraversing AST:"
def print_tree(node : Hecate::AST::Node, indent = 0)
  puts "#{"  " * indent}#{node.class.name.split("::").last}#{node}"
  node.children.each { |child| print_tree(child, indent + 1) }
end

print_tree(ast)

# Example with if statement: if (x < 5) { x = x + 1; }
if_stmt = If.new(
  LessThan.new(
    StringLit.new("x", make_span),  # In real usage, this would be a variable reference
    IntLit.new(5, make_span),
    make_span
  ),
  Block.new([
    Assignment.new(
      "x",
      Add.new(
        StringLit.new("x", make_span),  # Variable reference
        IntLit.new(1, make_span),
        make_span
      ),
      make_span
    )
  ], make_span),
  nil,
  make_span
)

puts "\n\nIf statement AST:"
print_tree(if_stmt)

puts "\nNode statistics:"
puts "  Total nodes: #{if_stmt.node_count}"
puts "  Tree depth: #{if_stmt.depth}"
puts "  Contains Assignment? #{if_stmt.contains?(Assignment)}"
puts "  All IntLit nodes: #{if_stmt.find_all(IntLit).map { |n| n.as(IntLit).value }.join(", ")}"