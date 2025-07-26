require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Create a minimal test for validation syntax
class MinimalValidationTest
  include Hecate::AST
  
  abstract_node Expr
  
  # Test node without validation first
  node IntLit < Expr, value : Int32
  
  # Test the block syntax
  macro test_block(&block)
    puts "Testing block:"
    {{ block.body }}
  end
  
  finalize_ast IntLit
end

describe "Minimal Validation Test" do
  it "creates nodes without validation blocks" do
    node = MinimalValidationTest::IntLit.new(make_span(), 42)
    node.value.should eq(42)
  end
end