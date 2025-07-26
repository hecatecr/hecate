require "../src/hecate-ast"

# Example demonstrating pretty printing and debugging utilities
module DebugExample
  include Hecate::AST
  
  # Define a simple language AST
  abstract_node Expr
  abstract_node Stmt
  
  # Expressions
  node IntLit < Expr, value: Int32
  node FloatLit < Expr, value: Float64
  node StringLit < Expr, value: String
  node BoolLit < Expr, value: Bool
  node Identifier < Expr, name: String
  
  node BinaryOp < Expr, left: Expr, right: Expr, operator: String
  node UnaryOp < Expr, operand: Expr, operator: String
  node Call < Expr, name: String, args: Array(Expr)
  
  # Statements
  node VarDecl < Stmt, name: String, type_name: String?, value: Expr?
  node Assignment < Stmt, name: String, value: Expr
  node Return < Stmt, value: Expr?
  node If < Stmt, condition: Expr, then_branch: Stmt, else_branch: Stmt?
  node While < Stmt, condition: Expr, body: Stmt
  node Block < Stmt, statements: Array(Stmt)
  node ExprStmt < Stmt, expr: Expr
  
  finalize_ast IntLit, FloatLit, StringLit, BoolLit, Identifier,
               BinaryOp, UnaryOp, Call,
               VarDecl, Assignment, Return, If, While, Block, ExprStmt
end

include DebugExample

def make_span(start = 0, stop = 10)
  Hecate::Core::Span.new(0_u32, start, stop)
end

# Build a sample AST
# Represents:
# ```
# func factorial(n: int): int {
#   if (n <= 1) {
#     return 1;
#   } else {
#     return n * factorial(n - 1);
#   }
# }
# ```

# Build the recursive call: factorial(n - 1)
recursive_call = Call.new(
  "factorial",
  [BinaryOp.new(
    Identifier.new("n", make_span),
    IntLit.new(1, make_span),
    "-",
    make_span
  )],
  make_span
)

# Build the multiplication: n * factorial(n - 1)
multiply = BinaryOp.new(
  Identifier.new("n", make_span),
  recursive_call,
  "*",
  make_span
)

# Build the if statement
if_stmt = If.new(
  BinaryOp.new(
    Identifier.new("n", make_span),
    IntLit.new(1, make_span),
    "<=",
    make_span
  ),
  Block.new([Return.new(IntLit.new(1, make_span), make_span)], make_span),
  Block.new([Return.new(multiply, make_span)], make_span),
  make_span
)

# The complete function body
func_body = Block.new([if_stmt], make_span)

puts "=== Pretty Printing Examples ==="
puts

puts "1. Default Pretty Print (indented):"
puts "─" * 40
puts func_body.pretty_print
puts

puts "2. Compact Pretty Print:"
puts "─" * 40
puts func_body.pretty_print(compact: true)
puts

puts "3. S-Expression Format:"
puts "─" * 40
puts func_body.to_sexp
puts

puts "4. Tree Visualization:"
puts "─" * 40
func_body.print_tree
puts

puts "5. JSON Serialization:"
puts "─" * 40
puts func_body.to_json
puts

puts "6. Custom Indentation (4 spaces):"
puts "─" * 40
puts func_body.pretty_print(indent_size: 4)
puts

# Demonstrate with a more complex example
puts "=== Complex Example ==="
puts

# Create a more complex AST with multiple statements
complex_ast = Block.new([
  VarDecl.new("x", "int", IntLit.new(10, make_span), make_span),
  VarDecl.new("y", "int", IntLit.new(20, make_span), make_span),
  
  While.new(
    BinaryOp.new(
      Identifier.new("x", make_span),
      IntLit.new(0, make_span),
      ">",
      make_span
    ),
    Block.new([
      Assignment.new(
        "y",
        BinaryOp.new(
          Identifier.new("y", make_span),
          Identifier.new("x", make_span),
          "+",
          make_span
        ),
        make_span
      ),
      Assignment.new(
        "x",
        BinaryOp.new(
          Identifier.new("x", make_span),
          IntLit.new(1, make_span),
          "-",
          make_span
        ),
        make_span
      ),
      ExprStmt.new(
        Call.new("print", [Identifier.new("y", make_span)], make_span),
        make_span
      )
    ], make_span),
    make_span
  ),
  
  Return.new(Identifier.new("y", make_span), make_span)
], make_span)

puts "Complex AST - Tree View:"
puts "─" * 40
complex_ast.print_tree
puts

puts "Complex AST - S-Expression:"
puts "─" * 40
puts complex_ast.to_sexp
puts

# Demonstrate source snippet extraction
source_code = <<-CODE
func factorial(n: int): int {
  if (n <= 1) {
    return 1;
  } else {
    return n * factorial(n - 1);
  }
}
CODE

# Create a node with realistic span
return_node = Return.new(
  IntLit.new(1, Hecate::Core::Span.new(0_u32, 51, 52)),
  Hecate::Core::Span.new(0_u32, 44, 53)
)

puts "=== Source Snippet Extraction ==="
puts "Node: #{return_node.to_compact_s}"
puts "Snippet:"
puts "─" * 40
if snippet = return_node.source_snippet(source_code, context_lines: 1)
  puts snippet
end
puts

# Demonstrate node statistics
puts "=== AST Statistics ==="
puts "Complex AST depth: #{complex_ast.depth}"
puts "Total node count: #{complex_ast.node_count}"
puts "Contains While loop? #{complex_ast.contains?(While)}"
puts "All IntLit values: #{complex_ast.find_all(IntLit).map(&.value).join(", ")}"
puts "All identifiers: #{complex_ast.find_all(Identifier).map(&.name).uniq.join(", ")}"