require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Create a test DSL context outside of describe blocks
class ValidationTestAST
  include Hecate::AST
  
  abstract_node Expr
  
  # Node without validation
  node IntLit < Expr, value : Int32
  
  # Node with validation
  node PositiveInt < Expr, value : Int32 do
    if value < 0
      errors << error("Value must be positive", span).build
    end
    if value > 1000000
      errors << warning("Very large integer", span).build
    end
  end
  
  # Node with complex validation
  node Add < Expr, left : Expr, right : Expr do
    # Test that we can access field values
    if left.is_a?(IntLit) && right.is_a?(IntLit)
      left_val = left.as(IntLit).value
      right_val = right.as(IntLit).value
      if left_val == 0
        errors << hint("Adding zero is redundant", left.span).build
      end
      if right_val == 0
        errors << hint("Adding zero is redundant", right.span).build
      end
    end
  end
  
  finalize_ast IntLit, PositiveInt, Add
end

# Test the validation functionality in the DSL
describe "Hecate::AST Validation" do
  
  it "creates nodes without validation blocks normally" do
    node = ValidationTestAST::IntLit.new(make_span(), 42)
    node.value.should eq(42)
    node.responds_to?(:validate).should be_false
  end
  
  it "creates nodes with validation blocks and validate method" do
    node = ValidationTestAST::PositiveInt.new(make_span(), 42)
    node.value.should eq(42)
    node.responds_to?(:validate).should be_true
  end
  
  it "validates positive integers correctly" do
    # Valid positive integer
    valid_node = ValidationTestAST::PositiveInt.new(make_span(), 42)
    errors = valid_node.validate
    errors.should be_empty
    
    # Invalid negative integer
    invalid_node = ValidationTestAST::PositiveInt.new(make_span(), -5)
    errors = invalid_node.validate
    errors.size.should eq(1)
    errors[0].severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
    errors[0].message.should contain("must be positive")
    
    # Large integer with warning
    large_node = ValidationTestAST::PositiveInt.new(make_span(), 2000000)
    errors = large_node.validate
    errors.size.should eq(1)
    errors[0].severity.should eq(Hecate::Core::Diagnostic::Severity::Warning)
    errors[0].message.should contain("Very large")
  end
  
  it "validates complex expressions" do
    left = ValidationTestAST::IntLit.new(make_span(0, 1), 0)
    right = ValidationTestAST::IntLit.new(make_span(2, 3), 5)
    add_node = ValidationTestAST::Add.new(make_span(0, 3), left, right)
    
    errors = add_node.validate
    errors.size.should eq(1)
    errors[0].severity.should eq(Hecate::Core::Diagnostic::Severity::Hint)
    errors[0].message.should contain("Adding zero is redundant")
  end
  
  it "provides helper methods for creating diagnostics" do
    node = ValidationTestAST::PositiveInt.new(make_span(), -1)
    errors = node.validate
    
    # The error should have proper span information
    error = errors[0]
    error.labels.size.should eq(1)
    error.labels[0].span.start_byte.should eq(0)
    error.labels[0].span.end_byte.should eq(10)
  end
end