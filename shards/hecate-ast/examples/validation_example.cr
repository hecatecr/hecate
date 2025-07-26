#!/usr/bin/env crystal

# Example demonstrating the AST validation framework in Hecate

require "../src/hecate-ast"

# Define a simple expression language with validation rules
module ExampleLang
  include Hecate::AST
  
  # Base types
  abstract_node Expr
  abstract_node Stmt
  
  # Integer literal with range validation
  node IntLit < Expr, value : Int32 do
    if value < -2147483648 || value > 2147483647
      errors << error("Integer literal out of range", span).build
    end
  end
  
  # Variable reference with name validation
  node VarRef < Expr, name : String do
    if name.empty?
      errors << error("Variable name cannot be empty", span).build
    elsif !name.matches?(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
      errors << error("Invalid variable name: #{name}", span).build
    elsif name.size > 255
      errors << warning("Variable name is unusually long", span).build
    end
    
    # Check for reserved keywords
    reserved = ["if", "else", "while", "for", "return", "class", "def"]
    if reserved.includes?(name)
      errors << error("Cannot use reserved keyword '#{name}' as variable name", span).build
    end
  end
  
  # Binary operation with type checking hints
  node BinOp < Expr, op : String, left : Expr, right : Expr do
    # Check for common mistakes
    case op
    when "/"
      if right.is_a?(IntLit) && right.as(IntLit).value == 0
        errors << error("Division by zero", right.span).build
      end
    when "+", "-"
      # Check for operations with zero
      if left.is_a?(IntLit) && left.as(IntLit).value == 0 && op == "+"
        errors << hint("Adding zero on the left is redundant", left.span).build
      elsif right.is_a?(IntLit) && right.as(IntLit).value == 0
        errors << hint("#{op == "+" ? "Adding" : "Subtracting"} zero is redundant", right.span).build
      end
    end
  end
  
  # Variable declaration with initialization check
  node VarDecl < Stmt, name : String, type_name : String?, init : Expr? do
    # Validate variable name
    if name.empty?
      errors << error("Variable name cannot be empty", span).build
    elsif !name.matches?(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
      errors << error("Invalid variable name: #{name}", span).build
    end
    
    # Warn about uninitialized variables
    if init.nil? && type_name.nil?
      errors << warning("Variable '#{name}' declared without type or initial value", span).build
    end
  end
  
  # Function call with argument validation
  node FuncCall < Expr, name : String, args : Array(Expr) do
    if name.empty?
      errors << error("Function name cannot be empty", span).build
    end
    
    # Check argument count
    if args.size > 255
      errors << error("Too many arguments (maximum: 255)", span).build
    elsif args.size > 10
      errors << warning("Function '#{name}' has #{args.size} arguments. Consider using named parameters or a configuration object", span).build
    end
  end
  
  finalize_ast IntLit, VarRef, BinOp, VarDecl, FuncCall
end

# Helper to create spans
def make_span(start_byte : Int32, end_byte : Int32)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Example 1: Valid AST
puts "=== Example 1: Valid AST ==="
valid_ast = ExampleLang::BinOp.new(
  make_span(0, 10),
  "+",
  ExampleLang::IntLit.new(make_span(0, 2), 42),
  ExampleLang::IntLit.new(make_span(5, 7), 10)
)

validator = Hecate::AST::ASTValidator.new
validator.visit(valid_ast)
puts "Valid AST validation: #{validator.summary}"
puts

# Example 2: AST with various validation errors
puts "=== Example 2: AST with Validation Errors ==="

# Division by zero
div_by_zero = ExampleLang::BinOp.new(
  make_span(0, 10),
  "/",
  ExampleLang::IntLit.new(make_span(0, 2), 42),
  ExampleLang::IntLit.new(make_span(5, 6), 0)
)

# Invalid variable name
invalid_var = ExampleLang::VarRef.new(make_span(12, 15), "123invalid")

# Reserved keyword as variable
reserved_var = ExampleLang::VarRef.new(make_span(17, 22), "class")

# Function with too many arguments
many_args = ExampleLang::FuncCall.new(
  make_span(24, 50),
  "process_data",
  Array(ExampleLang::Expr).new(15) { |i| ExampleLang::IntLit.new(make_span(30 + i*2, 31 + i*2), i).as(ExampleLang::Expr) }
)

# Build a compound expression
compound = ExampleLang::BinOp.new(
  make_span(0, 50),
  "+",
  div_by_zero,
  many_args
)

validator.clear
validator.visit(compound)

puts "Compound AST validation: #{validator.summary}"
puts "\nErrors found:"
validator.errors.each do |error|
  puts "  [#{error.severity}] #{error.message}"
  error.labels.each do |label|
    puts "    at #{label.span.start_byte}..#{label.span.end_byte}: #{label.message}"
  end
end
puts

# Example 3: Structural validation (cycle detection)
puts "=== Example 3: Structural Validation ==="

# Create a custom node type that can form cycles
class CyclicExpr < ExampleLang::Expr
  property next_expr : CyclicExpr?
  
  def initialize(span : Hecate::Core::Span)
    super(span)
  end
  
  def children : Array(Hecate::AST::Node)
    if n = @next_expr
      [n] of Hecate::AST::Node
    else
      [] of Hecate::AST::Node
    end
  end
  
  def accept(visitor)
    visitor.visit(self) if visitor.responds_to?(:visit)
  end
  
  def clone : self
    self
  end
  
  def ==(other : self) : Bool
    self.object_id == other.object_id
  end
end

# Create a cycle: A -> B -> C -> A
expr_a = CyclicExpr.new(make_span(0, 5))
expr_b = CyclicExpr.new(make_span(6, 10))
expr_c = CyclicExpr.new(make_span(11, 15))

expr_a.next_expr = expr_b
expr_b.next_expr = expr_c  
expr_c.next_expr = expr_a  # Creates cycle

structural_validator = Hecate::AST::StructuralValidator.new
structural_validator.validate_structure(expr_a)

puts "Structural validation: Found #{structural_validator.all_errors.size} errors"
structural_validator.all_errors.each do |error|
  puts "  [#{error.severity}] #{error.message}"
  error.labels.each do |label|
    puts "    #{label.style}: #{label.message}"
  end
  if help = error.help
    puts "    Help: #{help}"
  end
end
puts

# Example 4: Full validation (custom + structural)
puts "=== Example 4: Full Validation ==="

full_validator = Hecate::AST::FullValidator.new

# Create an AST with both custom validation errors and valid structure
ast_with_errors = ExampleLang::VarDecl.new(
  make_span(0, 20),
  "",              # Empty name - error
  "int",           # Has type
  ExampleLang::BinOp.new(
    make_span(10, 20),
    "+",
    ExampleLang::IntLit.new(make_span(10, 11), 0),  # Adding zero - hint
    ExampleLang::IntLit.new(make_span(15, 17), 42)
  )
)

errors = full_validator.validate(ast_with_errors)

if full_validator.valid?
  puts "AST is completely valid!"
else
  puts "Validation found issues:"
  
  # Group by severity
  by_severity = full_validator.errors_by_severity
  
  by_severity.each do |severity, severity_errors|
    puts "\n  #{severity} (#{severity_errors.size}):"
    severity_errors.each do |error|
      puts "    - #{error.message}"
    end
  end
end