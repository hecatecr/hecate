#!/usr/bin/env crystal

require "../src/hecate-ast"

# Define a simple expression language AST with validation rules
module MathAST
  include Hecate::AST

  # Base types
  abstract_node Expr

  # Integer literal with range validation
  node IntLit < Expr, value : Int32 do
    if value < -1000 || value > 1000
      errors << error("Integer value #{value} is out of allowed range", span)
        .help("Values must be between -1000 and 1000")
        .build
    end
  end

  # Variable reference with naming rules
  node VarRef < Expr, name : String do
    if name.empty?
      errors << error("Variable name cannot be empty", span).build
    elsif !name.matches?(/^[a-zA-Z][a-zA-Z0-9_]*$/)
      errors << error("Invalid variable name: '#{name}'", span)
        .help("Variable names must start with a letter and contain only letters, numbers, and underscores")
        .build
    elsif name.size > 32
      errors << warning("Variable name '#{name}' is very long", span)
        .note("Consider using a shorter, more descriptive name")
        .build
    end
  end

  # Binary operation with semantic validation
  node BinOp < Expr, op : String, left : Expr, right : Expr do
    case op
    when "/"
      # Check for division by zero
      if right.is_a?(IntLit)
        right_int = right.as(IntLit)
        if right_int.value == 0
          errors << error("Division by zero", span)
            .primary(right.span, "zero divisor here")
            .build
        end
      end
    when "*"
      # Warn about multiplication by zero
      zero_operand = false
      if left.is_a?(IntLit)
        left_int = left.as(IntLit)
        zero_operand = left_int.value == 0
      end
      if !zero_operand && right.is_a?(IntLit)
        right_int = right.as(IntLit)
        zero_operand = right_int.value == 0
      end
      if zero_operand
        errors << warning("Multiplication by zero always yields zero", span)
          .help("This expression can be simplified to 0")
          .build
      end
    when "+", "-"
      # Hint about identity operations
      if right.is_a?(IntLit)
        right_int = right.as(IntLit)
        if right_int.value == 0
          errors << hint("#{op == '+' ? "Adding" : "Subtracting"} zero has no effect", span)
            .primary(right.span, "zero here")
            .help("This operation can be removed")
            .build
        end
      end
    end
  end

  # Unary operation for functions that take one argument
  node UnaryFunc < Expr, name : String, arg : Expr do
    # Validate known functions
    case name
    when "abs", "sqrt", "sin", "cos", "tan", "log", "exp"
      # These are valid single-argument functions
    else
      errors << warning("Unknown function '#{name}'", span)
        .help("This might be a typo or undefined function")
        .build
    end
  end

  finalize_ast Expr, IntLit, VarRef, BinOp, UnaryFunc
end

# Helper to create spans for testing
def make_span(start_byte : Int32, end_byte : Int32) : Hecate::Core::Span
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Example 1: Valid expression
puts "=== Example 1: Valid Expression ==="
valid_expr = MathAST::BinOp.new(
  make_span(0, 7),
  "+",
  MathAST::IntLit.new(make_span(0, 1), 5),
  MathAST::IntLit.new(make_span(4, 7), 10)
)

validator = Hecate::AST::ASTValidator.new
validator.visit(valid_expr)
puts "Expression: 5 + 10"
puts "Valid: #{validator.valid?}"
puts "Summary: #{validator.summary}"
puts

# Example 2: Division by zero
puts "=== Example 2: Division by Zero ==="
div_by_zero = MathAST::BinOp.new(
  make_span(0, 9),
  "/",
  MathAST::IntLit.new(make_span(0, 3), 100),
  MathAST::IntLit.new(make_span(6, 7), 0)
)

validator.clear
validator.visit(div_by_zero)
puts "Expression: 100 / 0"
puts "Valid: #{validator.valid?}"
puts "Summary: #{validator.summary}"
validator.errors.each do |diagnostic|
  puts "  #{diagnostic.severity}: #{diagnostic.message}"
end
puts

# Example 3: Invalid variable name
puts "=== Example 3: Invalid Variable Name ==="
invalid_var = MathAST::VarRef.new(make_span(0, 8), "123invalid")

validator.clear
validator.visit(invalid_var)
puts "Expression: 123invalid"
puts "Valid: #{validator.valid?}"
puts "Summary: #{validator.summary}"
validator.errors.each do |diagnostic|
  puts "  #{diagnostic.severity}: #{diagnostic.message}"
  puts "    Help: #{diagnostic.help}" if diagnostic.help
end
puts

# Example 4: Complex expression with multiple issues
puts "=== Example 4: Complex Expression with Multiple Issues ==="
complex_expr = MathAST::BinOp.new(
  make_span(0, 15),
  "*",
  MathAST::IntLit.new(make_span(0, 4), 2000),  # Out of range
  MathAST::IntLit.new(make_span(7, 8), 0)      # Multiply by zero
)

validator.clear
validator.visit(complex_expr)
puts "Expression: 2000 * 0"
puts "Valid: #{validator.valid?}"
puts "Summary: #{validator.summary}"
puts "\nDiagnostics by severity:"
puts "Errors:"
validator.errors_only.each do |diagnostic|
  puts "  - #{diagnostic.message}"
end
puts "Warnings:"
validator.warnings_only.each do |diagnostic|
  puts "  - #{diagnostic.message}"
end
puts

# Example 5: Function validation
puts "=== Example 5: Function Validation ==="
func_expr = MathAST::UnaryFunc.new(
  make_span(0, 8),
  "sqrt",
  MathAST::IntLit.new(make_span(5, 7), 16)
)

validator.clear
validator.visit(func_expr)
puts "Expression: sqrt(16)"
puts "Valid: #{validator.valid?}"
puts "Summary: #{validator.summary}"

# Example 6: Unknown function
puts "\n=== Example 6: Unknown Function ==="
unknown_func = MathAST::UnaryFunc.new(
  make_span(0, 10),
  "foo",
  MathAST::IntLit.new(make_span(4, 6), 42)
)

validator.clear
validator.visit(unknown_func)
puts "Expression: foo(42)"
puts "Valid: #{validator.valid?}"
puts "Summary: #{validator.summary}"
validator.warnings_only.each do |diagnostic|
  puts "  #{diagnostic.severity}: #{diagnostic.message}"
  puts "    Help: #{diagnostic.help}" if diagnostic.help
end