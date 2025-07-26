require "../src/hecate-ast"

# Example demonstrating pretty printing and debugging utilities
module DebugExample
  include Hecate::AST

  # Define a simple language AST
  abstract_node Expr
  abstract_node Stmt

  # Expressions
  node IntLit < Expr, value : Int32
  node FloatLit < Expr, value : Float64
  node StringLit < Expr, value : String
  node BoolLit < Expr, value : Bool
  node Identifier < Expr, name : String

  node BinaryOp < Expr, left : Expr, right : Expr, operator : String
  node UnaryOp < Expr, operand : Expr, operator : String
  node Call < Expr, name : String, args : Array(Expr)

  # Statements
  node VarDecl < Stmt, name : String, type_name : String?, value : Expr?
  node Assignment < Stmt, name : String, value : Expr
  node Return < Stmt, value : Expr?
  node If < Stmt, condition : Expr, then_branch : Stmt, else_branch : Stmt?
  node While < Stmt, condition : Expr, body : Stmt
  node Block < Stmt, statements : Array(Stmt)
  node ExprStmt < Stmt, expr : Expr

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
  make_span,
  "factorial",
  [BinaryOp.new(
    make_span,
    Identifier.new(make_span, "n"),
    IntLit.new(make_span, 1),
    "-"
  )] of Expr
)

# Build the multiplication: n * factorial(n - 1)
multiply = BinaryOp.new(
  make_span,
  Identifier.new(make_span, "n"),
  recursive_call,
  "*"
)

# Build the if statement
if_stmt = If.new(
  make_span,
  BinaryOp.new(
    make_span,
    Identifier.new(make_span, "n"),
    IntLit.new(make_span, 1),
    "<="
  ),
  Block.new(make_span, [Return.new(make_span, IntLit.new(make_span, 1))] of Stmt),
  Block.new(make_span, [Return.new(make_span, multiply)] of Stmt)
)

# The complete function body
func_body = Block.new(make_span, [if_stmt] of Stmt)

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
complex_ast = Block.new(make_span, [
  VarDecl.new(make_span, "x", "int", IntLit.new(make_span, 10)),
  VarDecl.new(make_span, "y", "int", IntLit.new(make_span, 20)),

  While.new(
    make_span,
    BinaryOp.new(
      make_span,
      Identifier.new(make_span, "x"),
      IntLit.new(make_span, 0),
      ">"
    ),
    Block.new(make_span, [
      Assignment.new(
        make_span,
        "y",
        BinaryOp.new(
          make_span,
          Identifier.new(make_span, "y"),
          Identifier.new(make_span, "x"),
          "+"
        )
      ),
      Assignment.new(
        make_span,
        "x",
        BinaryOp.new(
          make_span,
          Identifier.new(make_span, "x"),
          IntLit.new(make_span, 1),
          "-"
        )
      ),
      ExprStmt.new(
        make_span,
        Call.new(make_span, "print", [Identifier.new(make_span, "y")] of Expr)
      ),
    ] of Stmt)
  ),

  Return.new(make_span, Identifier.new(make_span, "y")),
] of Stmt)

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
  Hecate::Core::Span.new(0_u32, 44, 53),
  IntLit.new(Hecate::Core::Span.new(0_u32, 51, 52), 1)
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
