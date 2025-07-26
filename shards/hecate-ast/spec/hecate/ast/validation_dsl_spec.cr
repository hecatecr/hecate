require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Define a simple AST with validation rules using the DSL
module TestAST
  include Hecate::AST
  
  # Base types
  abstract_node Expr
  abstract_node Stmt
  
  # Simple nodes without validation
  node IntLit < Expr, value : Int32
  node StringLit < Expr, value : String
  node Identifier < Expr, name : String
  
  # Nodes with validation rules
  node PositiveInt < Expr, value : Int32 do
    if value < 0
      errors << error("Value must be positive", span).build
    end
    
    if value > 1000000
      errors << warning("Large integer value", span).build
    end
  end
  
  node ValidIdentifier < Expr, name : String do
    if name.empty?
      errors << error("Identifier cannot be empty", span).build
    elsif !name.matches?(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
      errors << error("Invalid identifier format", span).build
    elsif name.size > 255
      errors << warning("Identifier is unusually long", span).build
    end
    
    # Check for reserved words
    reserved = ["class", "def", "module", "if", "else", "end"]
    if reserved.includes?(name)
      errors << hint("'#{name}' is a reserved keyword", span).build
    end
  end
  
  node Add < Expr, left : Expr, right : Expr do
    # Check for redundant additions
    if left.is_a?(IntLit) && left.as(IntLit).value == 0
      errors << hint("Adding zero on the left is redundant", left.span).build
    end
    
    if right.is_a?(IntLit) && right.as(IntLit).value == 0
      errors << hint("Adding zero on the right is redundant", right.span).build
    end
  end
  
  node VarDecl < Stmt, name : String, value : Expr? do
    if name.empty?
      errors << error("Variable name cannot be empty", span).build
    end
    
    if value.nil?
      errors << warning("Variable declared without initial value", span).build
    end
  end
  
  # Complex validation with multiple conditions
  node FunctionCall < Expr, name : String, args : Array(Expr) do
    if name.empty?
      errors << error("Function name cannot be empty", span).build
    end
    
    if args.size > 255
      errors << error("Too many arguments (max: 255)", span).build
    elsif args.size > 10
      errors << warning("Function has many arguments, consider using a struct", span).build
    end
    
    # Check for duplicate literal arguments
    literal_values = [] of Int32
    args.each_with_index do |arg, idx|
      if arg.is_a?(IntLit)
        int_arg = arg.as(IntLit)
        if literal_values.includes?(int_arg.value)
          errors << hint("Duplicate literal value #{int_arg.value} in arguments", arg.span).build
        else
          literal_values << int_arg.value
        end
      end
    end
  end
  
  finalize_ast IntLit, StringLit, Identifier, PositiveInt, ValidIdentifier, Add, VarDecl, FunctionCall
end

describe "Validation DSL" do
  it "validates positive integers" do
    valid = TestAST::PositiveInt.new(make_span(), 42)
    invalid = TestAST::PositiveInt.new(make_span(), -5)
    large = TestAST::PositiveInt.new(make_span(), 2000000)
    
    valid.validate.should be_empty
    
    invalid_errors = invalid.validate
    invalid_errors.size.should eq(1)
    invalid_errors.first.message.should contain("must be positive")
    invalid_errors.first.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
    
    large_errors = large.validate
    large_errors.size.should eq(1)
    large_errors.first.severity.should eq(Hecate::Core::Diagnostic::Severity::Warning)
  end
  
  it "validates identifiers" do
    valid = TestAST::ValidIdentifier.new(make_span(), "myVariable")
    empty = TestAST::ValidIdentifier.new(make_span(), "")
    invalid_format = TestAST::ValidIdentifier.new(make_span(), "123invalid")
    reserved = TestAST::ValidIdentifier.new(make_span(), "class")
    long = TestAST::ValidIdentifier.new(make_span(), "a" * 300)
    
    valid.validate.should be_empty
    
    empty_errors = empty.validate
    empty_errors.any? { |e| e.message.includes?("cannot be empty") }.should be_true
    
    format_errors = invalid_format.validate  
    format_errors.any? { |e| e.message.includes?("Invalid identifier format") }.should be_true
    
    reserved_errors = reserved.validate
    reserved_errors.any? { |e| e.severity == Hecate::Core::Diagnostic::Severity::Hint }.should be_true
    
    long_errors = long.validate
    long_errors.any? { |e| e.severity == Hecate::Core::Diagnostic::Severity::Warning }.should be_true
  end
  
  it "validates addition operations" do
    normal = TestAST::Add.new(
      make_span(0, 10),
      TestAST::IntLit.new(make_span(0, 1), 5),
      TestAST::IntLit.new(make_span(5, 6), 3)
    )
    
    left_zero = TestAST::Add.new(
      make_span(0, 10),
      TestAST::IntLit.new(make_span(0, 1), 0),
      TestAST::IntLit.new(make_span(5, 6), 5)
    )
    
    right_zero = TestAST::Add.new(
      make_span(0, 10),
      TestAST::IntLit.new(make_span(0, 1), 5),
      TestAST::IntLit.new(make_span(5, 6), 0)
    )
    
    normal.validate.should be_empty
    
    left_errors = left_zero.validate
    left_errors.size.should eq(1)
    left_errors.first.severity.should eq(Hecate::Core::Diagnostic::Severity::Hint)
    
    right_errors = right_zero.validate
    right_errors.size.should eq(1)
    right_errors.first.message.should contain("redundant")
  end
  
  it "validates variable declarations" do
    valid = TestAST::VarDecl.new(make_span(), "myVar", TestAST::IntLit.new(make_span(), 42))
    no_value = TestAST::VarDecl.new(make_span(), "myVar", nil)
    empty_name = TestAST::VarDecl.new(make_span(), "", TestAST::IntLit.new(make_span(), 42))
    
    valid.validate.should be_empty
    
    no_value_errors = no_value.validate
    no_value_errors.any? { |e| e.severity == Hecate::Core::Diagnostic::Severity::Warning }.should be_true
    
    empty_errors = empty_name.validate
    empty_errors.any? { |e| e.severity == Hecate::Core::Diagnostic::Severity::Error }.should be_true
  end
  
  it "validates function calls" do
    normal = TestAST::FunctionCall.new(
      make_span(),
      "myFunc",
      [TestAST::IntLit.new(make_span(), 1), TestAST::IntLit.new(make_span(), 2)] of TestAST::Expr
    )
    
    many_args = TestAST::FunctionCall.new(
      make_span(),
      "complexFunc",
      Array(TestAST::Expr).new(15) { |i| TestAST::IntLit.new(make_span(), i).as(TestAST::Expr) }
    )
    
    duplicate_args = TestAST::FunctionCall.new(
      make_span(),
      "func",
      [
        TestAST::IntLit.new(make_span(0, 1), 5),
        TestAST::IntLit.new(make_span(2, 3), 5),
        TestAST::IntLit.new(make_span(4, 5), 3)
      ] of TestAST::Expr
    )
    
    normal.validate.should be_empty
    
    many_errors = many_args.validate
    many_errors.any? { |e| e.severity == Hecate::Core::Diagnostic::Severity::Warning }.should be_true
    
    dup_errors = duplicate_args.validate
    dup_errors.any? { |e| e.message.includes?("Duplicate literal value") }.should be_true
  end
  
  it "works with ASTValidator visitor" do
    # Create an AST with mixed valid and invalid nodes
    validator = Hecate::AST::ASTValidator.new
    
    # Valid tree
    valid_tree = TestAST::Add.new(
      make_span(),
      TestAST::PositiveInt.new(make_span(), 5),
      TestAST::PositiveInt.new(make_span(), 10)
    )
    
    validator.visit(valid_tree)
    validator.valid?.should be_true
    
    # Invalid tree
    validator.clear
    invalid_tree = TestAST::Add.new(
      make_span(),
      TestAST::PositiveInt.new(make_span(), -5),  # Error
      TestAST::IntLit.new(make_span(), 0)         # Hint for adding zero
    )
    
    validator.visit(invalid_tree)
    validator.valid?.should be_false
    validator.error_count.should eq(1)
    validator.hint_count.should eq(1)
  end
end