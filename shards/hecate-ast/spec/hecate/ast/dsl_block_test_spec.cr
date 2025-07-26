require "../../spec_helper"

# Test the actual DSL with block syntax

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Test 1: Restore the fields parameter and add block support
module TestDSL1
  include Hecate::AST
  
  abstract_node Expr
  
  # Try with the actual DSL - this was failing before
  node IntLit < Expr, value : Int32
  
  # Now with a block
  node PositiveInt < Expr, value : Int32 do
    if value < 0
      errors << error("Value must be positive", span).build
    end
  end
  
  finalize_ast IntLit, PositiveInt
end

describe "DSL with block syntax" do
  it "creates nodes with the current DSL" do
    node = TestDSL1::IntLit.new(make_span(), 42)
    node.value.should eq(42)
  end
  
  it "handles node with validation block" do
    node = TestDSL1::PositiveInt.new(make_span(), -5)
    node.value.should eq(-5)
    
    # Check if validate method exists
    node.responds_to?(:validate).should be_true
    
    if node.responds_to?(:validate)
      errors = node.validate
      errors.size.should eq(1)
      errors.first.message.should contain("must be positive")
    end
  end
end