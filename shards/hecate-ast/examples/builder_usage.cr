require "../src/hecate-ast"

# Example demonstrating the Builder Pattern DSL for AST construction
# This shows how to create complex AST structures ergonomically

# Define a simple expression language AST
module SimpleExpr
  include Hecate::AST

  # Abstract base type
  abstract_node Expr

  # Simple expression nodes
  node IntLit < Expr, value : Int32
  node Identifier < Expr, name : String
  node BinaryOp < Expr, operator : String, left : Expr, right : Expr
  node UnaryOp < Expr, operator : String, operand : Expr

  # Finalize the AST
  finalize_ast IntLit, Identifier, BinaryOp, UnaryOp

  # Generate builder methods
  generate_builder IntLit, value : Int32
  generate_builder Identifier, name : String
  generate_builder BinaryOp, operator : String, left : Expr, right : Expr
  generate_builder UnaryOp, operator : String, operand : Expr

  # Add convenience methods
  add_builder_conveniences
end

# Create helper for span creation
def span(start = 0, end_pos = 0)
  Hecate::Core::Span.new(0_u32, start, end_pos)
end

puts "=== Builder Pattern DSL Example ==="
puts

# Example 1: Simple arithmetic expression
# Represents: (1 + 2) * 3
puts "Example 1: Simple arithmetic expression: (1 + 2) * 3"

# Manual construction (verbose)
manual_expr = SimpleExpr::BinaryOp.new(
  span(),
  "*",
  SimpleExpr::BinaryOp.new(
    span(),
    "+",
    SimpleExpr::IntLit.new(span(), 1),
    SimpleExpr::IntLit.new(span(), 2)
  ),
  SimpleExpr::IntLit.new(span(), 3)
)

# Builder construction (ergonomic)
builder_expr = SimpleExpr::Builder.build do
  binary_op("*",
    binary_op("+", int_lit(1), int_lit(2)),
    int_lit(3))
end

puts "Manual construction: #{manual_expr}"
puts "Builder construction: #{builder_expr}"
puts "Are they structurally equivalent? #{manual_expr.operator == builder_expr.operator}"
puts

# Example 2: Unary expression
# Represents: -(x + 1)
puts "Example 2: Unary expression: -(x + 1)"

unary_expr = SimpleExpr::Builder.build do
  unary_op("-", binary_op("+", identifier("x"), int_lit(1)))
end

puts "Unary expression: #{unary_expr}"
puts "Operator: #{unary_expr.operator}"
puts "Operand type: #{unary_expr.operand.class}"
puts

# Example 3: Nested binary operations
# Represents: a + b * c - d
puts "Example 3: Complex expression: a + b * c - d"

complex_expr = SimpleExpr::Builder.build do
  binary_op("-",
    binary_op("+",
      identifier("a"),
      binary_op("*", identifier("b"), identifier("c"))
    ),
    identifier("d")
  )
end

puts "Complex expression: #{complex_expr}"
puts "Left operand type: #{complex_expr.left.class}"
puts "Right operand type: #{complex_expr.right.class}"
puts

# Example 4: Span propagation demonstration
puts "Example 4: Span propagation with span_for helper"

# Create nodes with specific spans to demonstrate span calculation
left_node = SimpleExpr::Builder.int_lit(10, span(0, 2))  # "10" at position 0-2
right_node = SimpleExpr::Builder.int_lit(20, span(5, 7)) # "20" at position 5-7

# Calculate encompassing span
encompassing_span = SimpleExpr::Builder.span_for(left_node, right_node)
puts "Left span: #{left_node.span}"
puts "Right span: #{right_node.span}"
puts "Encompassing span: #{encompassing_span}"

# Create parent node with calculated span
addition = SimpleExpr::Builder.binary_op("+", left_node, right_node, encompassing_span)
puts "Addition with calculated span: #{addition.span}"
puts

# Example 5: Convenience methods
puts "Example 5: Convenience methods for optional values and lists"

# Using some/none for optional values
optional_expr = SimpleExpr::Builder.some(SimpleExpr::Builder.int_lit(42))
puts "Optional expression: #{optional_expr.inspect}"

nil_expr = SimpleExpr::Builder.none
puts "Nil expression: #{nil_expr.inspect}"

# Using list for arrays of expressions
expr_list = SimpleExpr::Builder.list(
  SimpleExpr::Builder.int_lit(1),
  SimpleExpr::Builder.int_lit(2),
  SimpleExpr::Builder.identifier("x")
)
puts "Expression list: #{expr_list.map(&.class.name)}"
puts

puts "=== Integration Test: Building a Complex Expression Tree ==="

# Build a complex expression that demonstrates all node types
# Represents: -(a + (b * 2)) - (x + y)
complex_tree = SimpleExpr::Builder.build do
  binary_op("-",
    unary_op("-",
      binary_op("+",
        identifier("a"),
        binary_op("*", identifier("b"), int_lit(2))
      )
    ),
    binary_op("+", identifier("x"), identifier("y"))
  )
end

puts "Complex expression tree created successfully!"
puts "Root node type: #{complex_tree.class}"
puts "Root operator: #{complex_tree.operator}"

# Traverse the tree to show structure
def show_structure(node, indent = 0)
  prefix = "  " * indent
  case node
  when SimpleExpr::IntLit
    puts "#{prefix}IntLit(#{node.value})"
  when SimpleExpr::Identifier
    puts "#{prefix}Identifier(#{node.name})"
  when SimpleExpr::BinaryOp
    puts "#{prefix}BinaryOp(#{node.operator})"
    show_structure(node.left, indent + 1)
    show_structure(node.right, indent + 1)
  when SimpleExpr::UnaryOp
    puts "#{prefix}UnaryOp(#{node.operator})"
    show_structure(node.operand, indent + 1)
  end
end

puts "\nTree structure:"
show_structure(complex_tree)

puts
puts "=== Builder Pattern Benefits ==="
puts "✅ Automatic span handling with DEFAULT_SPAN"
puts "✅ Clean, readable DSL syntax with build blocks"
puts "✅ Type-safe construction with Crystal's type system"
puts "✅ Span propagation helpers for accurate source mapping"
puts "✅ Convenience methods for optional values and lists"
puts "✅ No manual span tracking required in most cases"
puts "✅ Significantly less verbose than manual construction"
