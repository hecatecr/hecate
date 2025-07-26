require "../../spec_helper"

# Test AST module that uses the validation DSL
module TestValidationAST
  include Hecate::AST
  
  # Base types
  abstract_node Expr
  abstract_node Stmt
  
  # Node with simple validation
  node IntLit < Expr, value : Int32 do
    # Since value is already Int32, check for special values instead
    if value == Int32::MIN
      errors << warning("Integer at minimum value", span)
        .help("Consider using a larger integer type")
        .build
    elsif value == Int32::MAX
      errors << warning("Integer at maximum value", span)
        .help("Consider using a larger integer type")
        .build
    end
  end
  
  # Node with multiple validations
  node PositiveInt < Expr, value : Int32 do
    if value < 0
      errors << error("Value must be positive", span).build
    end
    
    if value > 1000000
      errors << warning("Very large integer value", span)
        .help("Consider using a smaller value or a different type")
        .build
    end
  end
  
  # Node with cross-field validation
  node RangeExpr < Expr, start_val : Int32, end_val : Int32 do
    if start_val > end_val
      errors << error("Range start must be less than or equal to end", span)
        .primary(span, "invalid range here")
        .help("Swap the start and end values")
        .build
    end
    
    if end_val - start_val > 10000
      errors << warning("Very large range", span)
        .note("Range contains #{end_val - start_val + 1} elements")
        .build
    end
  end
  
  # Node without validation (should work fine)
  node StringLit < Expr, value : String
  
  # Node with child validation
  node BinaryOp < Expr, left : Expr, right : Expr, op : String do
    # Check for redundant operations
    if op == "+" && left.is_a?(IntLit)
      left_int = left.as(IntLit)
      if left_int.value == 0
        errors << hint("Adding zero on the left is redundant", left.span)
          .help("Remove the zero operand")
          .build
      end
    end
    
    if op == "*" && right.is_a?(IntLit)
      right_int = right.as(IntLit)
      if right_int.value == 0
        errors << warning("Multiplication by zero", span)
          .primary(right.span, "zero here")
          .help("This expression always evaluates to zero")
          .build
      elsif right_int.value == 1
        errors << hint("Multiplication by one is redundant", right.span).build
      end
    end
  end
  
  # Node with validation using helper methods
  node Identifier < Expr, name : String do
    if name.empty?
      errors << error("Identifier cannot be empty", span).build
    elsif !name.matches?(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
      errors << error("Invalid identifier: #{name}", span)
        .help("Identifiers must start with a letter or underscore and contain only alphanumeric characters and underscores")
        .build
    elsif name.size > 255
      errors << warning("Identifier is very long", span)
        .note("Length: #{name.size} characters")
        .build
    end
  end
  
  # Finalize to generate visitor methods
  finalize_ast Expr, Stmt, IntLit, PositiveInt, RangeExpr, StringLit, BinaryOp, Identifier
end

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

describe "AST Validation DSL" do
  it "validates simple integer constraints" do
    validator = Hecate::AST::ASTValidator.new
    
    # Valid integer
    valid_int = TestValidationAST::IntLit.new(make_span(), 42)
    validator.visit(valid_int)
    validator.valid?.should be_true
    
    # Integer at maximum value
    validator.clear
    max_int = TestValidationAST::IntLit.new(make_span(), Int32::MAX)
    validator.visit(max_int)
    validator.valid?.should be_true  # Warnings don't affect validity
    validator.warning_count.should eq(1)
    validator.warnings_only.first.message.should contain("maximum value")
  end
  
  it "validates positive integer with warnings" do
    validator = Hecate::AST::ASTValidator.new
    
    # Negative value (error)
    negative_int = TestValidationAST::PositiveInt.new(make_span(), -5)
    validator.visit(negative_int)
    validator.valid?.should be_false
    validator.error_count.should eq(1)
    
    # Large value (warning)
    validator.clear
    large_int = TestValidationAST::PositiveInt.new(make_span(), 2000000)
    validator.visit(large_int)
    validator.valid?.should be_true  # Warnings don't make it invalid
    validator.warning_count.should eq(1)
    validator.warnings_only.first.message.should contain("Very large")
  end
  
  it "validates cross-field constraints in ranges" do
    validator = Hecate::AST::ASTValidator.new
    
    # Valid range
    valid_range = TestValidationAST::RangeExpr.new(make_span(), 1, 10)
    validator.visit(valid_range)
    validator.valid?.should be_true
    
    # Invalid range (start > end)
    validator.clear
    invalid_range = TestValidationAST::RangeExpr.new(make_span(), 10, 5)
    validator.visit(invalid_range)
    validator.valid?.should be_false
    validator.error_count.should eq(1)
    validator.errors.first.message.should contain("start must be less than")
    
    # Large range (warning)
    validator.clear
    large_range = TestValidationAST::RangeExpr.new(make_span(), 1, 20000)
    validator.visit(large_range)
    validator.valid?.should be_true
    validator.warning_count.should eq(1)
  end
  
  it "validates nodes without validation rules" do
    validator = Hecate::AST::ASTValidator.new
    
    # String literal has no validation
    str_lit = TestValidationAST::StringLit.new(make_span(), "hello")
    validator.visit(str_lit)
    validator.valid?.should be_true
    validator.errors.should be_empty
  end
  
  it "validates binary operations with context-aware rules" do
    validator = Hecate::AST::ASTValidator.new
    
    # Addition with zero on left
    zero_lit = TestValidationAST::IntLit.new(make_span(0, 1), 0)
    five_lit = TestValidationAST::IntLit.new(make_span(4, 5), 5)
    add_zero = TestValidationAST::BinaryOp.new(make_span(0, 5), zero_lit, five_lit, "+")
    
    validator.visit(add_zero)
    validator.valid?.should be_true  # Hints don't affect validity
    validator.hint_count.should eq(1)
    validator.hints_only.first.message.should contain("redundant")
    
    # Multiplication by zero
    validator.clear
    mult_zero = TestValidationAST::BinaryOp.new(make_span(0, 5), five_lit, zero_lit, "*")
    validator.visit(mult_zero)
    validator.warning_count.should eq(1)
    validator.warnings_only.first.message.should contain("Multiplication by zero")
    
    # Multiplication by one
    validator.clear
    one_lit = TestValidationAST::IntLit.new(make_span(4, 5), 1)
    mult_one = TestValidationAST::BinaryOp.new(make_span(0, 5), five_lit, one_lit, "*")
    validator.visit(mult_one)
    validator.hint_count.should eq(1)
  end
  
  it "validates identifier naming rules" do
    validator = Hecate::AST::ASTValidator.new
    
    # Valid identifier
    valid_id = TestValidationAST::Identifier.new(make_span(), "my_var123")
    validator.visit(valid_id)
    validator.valid?.should be_true
    
    # Empty identifier
    validator.clear
    empty_id = TestValidationAST::Identifier.new(make_span(), "")
    validator.visit(empty_id)
    validator.valid?.should be_false
    validator.errors.first.message.should contain("cannot be empty")
    
    # Invalid characters
    validator.clear
    invalid_id = TestValidationAST::Identifier.new(make_span(), "my-var!")
    validator.visit(invalid_id)
    validator.valid?.should be_false
    validator.errors.first.message.should contain("Invalid identifier")
    
    # Very long identifier
    validator.clear
    long_name = "a" * 300
    long_id = TestValidationAST::Identifier.new(make_span(), long_name)
    validator.visit(long_id)
    validator.valid?.should be_true
    validator.warning_count.should eq(1)
  end
  
  it "collects all validation errors from complex AST" do
    validator = Hecate::AST::ASTValidator.new
    
    # Create complex AST with multiple validation issues:
    # BinaryOp(*, PositiveInt(-1), IntLit(0))
    negative_pos = TestValidationAST::PositiveInt.new(make_span(0, 2), -1)  # Error
    zero_lit = TestValidationAST::IntLit.new(make_span(4, 5), 0)
    mult_op = TestValidationAST::BinaryOp.new(make_span(0, 5), negative_pos, zero_lit, "*")  # Warning
    
    validator.visit(mult_op)
    
    # Should have both the error from PositiveInt and warning from BinaryOp
    validator.error_count.should eq(1)
    validator.warning_count.should eq(1)
    validator.summary.should contain("1 errors, 1 warnings")
  end
  
  it "provides helpful diagnostic messages with spans" do
    validator = Hecate::AST::ASTValidator.new
    
    # Create a range with invalid bounds
    invalid_range = TestValidationAST::RangeExpr.new(make_span(10, 20), 100, 50)
    validator.visit(invalid_range)
    
    error = validator.errors.first
    error.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
    error.message.should contain("Range start must be less than")
    error.labels.first.span.start_byte.should eq(10)
    error.labels.first.span.end_byte.should eq(20)
    error.help.should_not be_nil
    error.help.not_nil!.should contain("Swap the start and end")
  end
end