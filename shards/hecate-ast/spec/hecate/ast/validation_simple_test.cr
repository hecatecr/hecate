require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Simple test to debug the block issue
class SimpleTest
  include Hecate::AST
  
  abstract_node Expr
  
  # Try without a block first
  node TestNodeSimple < Expr, value : Int32
  
  finalize_ast TestNodeSimple
end

describe "Simple Validation Block Test" do
  it "creates node without block" do
    node = SimpleTest::TestNodeSimple.new(make_span(), 42)
    node.should be_a(SimpleTest::TestNodeSimple)
    node.value.should eq(42)
  end
end