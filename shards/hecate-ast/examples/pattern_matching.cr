require "../src/hecate-ast"
require "hecate-core"

# Example demonstrating pattern matching and type discrimination features
# of the Hecate AST framework

# Define a simple expression language AST
module ExampleAST
  include Hecate::AST
  
  # Abstract base types
  abstract_node Expr
  abstract_node Stmt
  
  # Expression nodes
  node IntLit < Expr, value : Int32
  node FloatLit < Expr, value : Float64
  node StringLit < Expr, value : String
  node BinaryOp < Expr, left : Expr, right : Expr, operator : String
  node UnaryOp < Expr, operand : Expr, operator : String
  node VarRef < Expr, name : String
  
  # Statement nodes
  node VarDecl < Stmt, name : String, value : Expr?
  node ExprStmt < Stmt, expression : Expr
  node Block < Stmt, statements : Array(Stmt)
  node If < Stmt, condition : Expr, then_branch : Stmt, else_branch : Stmt?
  
  # Finalize AST to generate visitors and type predicates
  finalize_ast IntLit, FloatLit, StringLit, BinaryOp, UnaryOp, VarRef,
               VarDecl, ExprStmt, Block, If
end

def make_span(start : Int32 = 0, length : Int32 = 1)
  Hecate::Core::Span.new(0_u32, start, start + length)
end

puts "=== Hecate AST Pattern Matching Examples ===\n"

# Create some example AST nodes
span = make_span(0, 10)

# Simple expressions: 42, 3.14, "hello"
int_lit = ExampleAST::IntLit.new(span, 42)
float_lit = ExampleAST::FloatLit.new(span, 3.14)
string_lit = ExampleAST::StringLit.new(span, "hello")

# Binary operation: 10 + 5
binary_op = ExampleAST::BinaryOp.new(
  span,
  ExampleAST::IntLit.new(span, 10),
  ExampleAST::IntLit.new(span, 5),
  "+"
)

# Variable declaration: let x = 42
var_decl = ExampleAST::VarDecl.new(span, "x", int_lit)

# Expression statement: print("hello")
expr_stmt = ExampleAST::ExprStmt.new(span, string_lit)

# Create a collection of mixed AST nodes
nodes = [
  int_lit.as(Hecate::AST::Node),
  float_lit.as(Hecate::AST::Node),
  binary_op.as(Hecate::AST::Node),
  var_decl.as(Hecate::AST::Node),
  expr_stmt.as(Hecate::AST::Node)
]

puts "1. Type Predicate Methods\n"
puts "   Using generated predicate methods for type checking:"

nodes.each_with_index do |node, i|
  puts "   Node #{i + 1}:"
  puts "     int_lit?    = #{node.int_lit?}"
  puts "     binary_op?  = #{node.binary_op?}"
  puts "     var_decl?   = #{node.var_decl?}"
  puts "     expression? = #{node.expression?}"
  puts "     statement?  = #{node.statement?}"
  puts "     type symbol = #{node.node_type_symbol}"
  puts
end

puts "2. Crystal case/when Pattern Matching\n"
puts "   Using Crystal's native case/when for pattern matching:"

nodes.each_with_index do |node, i|
  description = case node
                when ExampleAST::IntLit
                  "Integer literal: #{node.value}"
                when ExampleAST::FloatLit
                  "Float literal: #{node.value}"
                when ExampleAST::StringLit
                  "String literal: \"#{node.value}\""
                when ExampleAST::BinaryOp
                  left_desc = case node.left
                             when ExampleAST::IntLit
                               node.left.as(ExampleAST::IntLit).value.to_s
                             else
                               "complex"
                             end
                  right_desc = case node.right
                              when ExampleAST::IntLit
                                node.right.as(ExampleAST::IntLit).value.to_s
                              else
                                "complex"
                              end
                  "Binary operation: #{left_desc} #{node.operator} #{right_desc}"
                when ExampleAST::VarDecl
                  value_desc = node.value ? "with initial value" : "without initial value"
                  "Variable declaration: #{node.name} #{value_desc}"
                when ExampleAST::ExprStmt
                  "Expression statement"
                else
                  "Unknown node type"
                end
  
  puts "   Node #{i + 1}: #{description}"
end

puts "\n3. Abstract Type Pattern Matching\n"
puts "   Matching against abstract base types (Expr vs Stmt):"

nodes.each_with_index do |node, i|
  category = case node
            when ExampleAST::Expr
              "Expression"
            when ExampleAST::Stmt
              "Statement"
            else
              "Unknown"
            end
  
  puts "   Node #{i + 1}: #{category}"
end

puts "\n4. Conditional Type Checking\n"
puts "   Using predicate methods in conditional logic:"

expressions = nodes.select(&.expression?)
statements = nodes.select(&.statement?)

puts "   Found #{expressions.size} expressions and #{statements.size} statements"

# Process expressions differently from statements
expressions.each do |expr|
  if expr.int_lit?
    puts "   Processing integer: #{expr.as(ExampleAST::IntLit).value}"
  elsif expr.binary_op?
    puts "   Processing binary operation"
  else
    puts "   Processing other expression type: #{expr.node_type_symbol}"
  end
end

statements.each do |stmt|
  if stmt.var_decl?
    decl = stmt.as(ExampleAST::VarDecl)
    puts "   Processing variable declaration: #{decl.name}"
  else
    puts "   Processing other statement type: #{stmt.node_type_symbol}"
  end
end

puts "\n5. Exhaustive Pattern Matching Validation\n"
puts "   Using exhaustive matching helpers for validation:"

# Get all possible node types
all_types = Hecate::AST::Node.all_node_types
puts "   All node types in this AST: #{all_types.join(", ")}"

# Check if a pattern match is exhaustive
handled_types = [:int_lit, :float_lit, :binary_op, :var_decl, :expr_stmt]
is_exhaustive = Hecate::AST::Node.exhaustive_match?(handled_types)
puts "   Pattern covering #{handled_types.join(", ")} is exhaustive: #{is_exhaustive}"

# Find missing types
missing_types = Hecate::AST::Node.missing_from_match(handled_types)
if missing_types.any?
  puts "   Missing types: #{missing_types.join(", ")}"
else
  puts "   No missing types - pattern is complete!"
end

# Demonstrate validation
puts "\n   Validating exhaustive pattern match:"
begin
  complete_pattern = [:int_lit, :float_lit, :string_lit, :binary_op, :unary_op, :var_ref,
                     :var_decl, :expr_stmt, :block, :if]
  Hecate::AST::Node.validate_exhaustive_match(complete_pattern)
  puts "   ✓ Complete pattern validation passed"
rescue ex
  puts "   ✗ Validation failed: #{ex.message}"
end

begin
  incomplete_pattern = [:int_lit, :binary_op]  # Missing many types
  Hecate::AST::Node.validate_exhaustive_match(incomplete_pattern)
  puts "   ✗ This should not print - validation should have failed"
rescue ex
  puts "   ✓ Incomplete pattern correctly rejected: #{ex.message}"
end

puts "\n6. Symbol-based Pattern Matching\n"
puts "   Using node type symbols for pattern matching:"

nodes.each_with_index do |node, i|
  symbol_desc = case node.node_type_symbol
                when :int_lit
                  "Integer literal"
                when :float_lit
                  "Float literal"
                when :string_lit
                  "String literal"
                when :binary_op
                  "Binary operation"
                when :var_decl
                  "Variable declaration"
                when :expr_stmt
                  "Expression statement"
                else
                  "Other type: #{node.node_type_symbol}"
                end
  
  puts "   Node #{i + 1} (#{node.node_type_symbol}): #{symbol_desc}"
end

puts "\n7. Advanced Pattern Matching with Guards\n"
puts "   Combining type checking with value guards:"

nodes.each_with_index do |node, i|
  result = case node
           when ExampleAST::IntLit
             if node.value < 0
               "Negative integer: #{node.value}"
             elsif node.value == 0
               "Zero"
             elsif node.value > 100
               "Large integer: #{node.value}"
             else
               "Small positive integer: #{node.value}"
             end
           when ExampleAST::BinaryOp
             case node.operator
             when "+"
               "Addition"
             when "-"
               "Subtraction"
             when "*"
               "Multiplication"
             when "/"
               "Division"
             else
               "Other binary operation: #{node.operator}"
             end
           when ExampleAST::VarDecl
             if node.value
               "Variable #{node.name} with initializer"
             else
               "Variable #{node.name} without initializer"
             end
           else
             "Other node type"
           end
  
  puts "   Node #{i + 1}: #{result}"
end

puts "\n=== Pattern Matching Examples Complete ===\n"
puts "This example demonstrates:"
puts "• Type predicate methods (int_lit?, binary_op?, etc.)"
puts "• Crystal's case/when pattern matching with AST nodes"
puts "• Abstract type matching (Expr vs Stmt)"
puts "• Conditional type checking with predicates"
puts "• Exhaustive pattern matching validation"
puts "• Symbol-based pattern matching"
puts "• Advanced pattern matching with guards"
puts "\nThese features make it easy to write robust, type-safe"
puts "code that works with AST nodes in Crystal!"