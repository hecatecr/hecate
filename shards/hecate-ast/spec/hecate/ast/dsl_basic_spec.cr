require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Test that the DSL module loads without errors
describe "Hecate::AST DSL Module" do
  it "loads the DSL module" do
    Hecate::AST::VERSION.should eq("0.1.0")
  end

  it "can create subclasses of Node" do
    # Just verify we can create instances of concrete subclasses
    node = TestIntLit.new(42, make_span(0, 10))
    node.should be_a(Hecate::AST::Node)
    node.should be_a(TestExpr)
    node.value.should eq(42)
  end
end

# Test macro expansion directly
abstract class TestExpr < Hecate::AST::Node
end

class TestIntLit < TestExpr
  getter value : Int32
  
  def initialize(@value : Int32, span : Hecate::Core::Span)
    super(span)
  end
  
  def accept(visitor)
    visitor.visit_test_int_lit(self)
  end
  
  def children : Array(Hecate::AST::Node)
    [] of Hecate::AST::Node
  end
  
  def clone : self
    TestIntLit.new(@value, @span)
  end
  
  def ==(other : self) : Bool
    super && @value == other.value
  end
end

class TestAdd < TestExpr
  getter left : TestExpr
  getter right : TestExpr
  
  def initialize(@left : TestExpr, @right : TestExpr, span : Hecate::Core::Span)
    super(span)
  end
  
  def accept(visitor)
    visitor.visit_test_add(self)
  end
  
  def children : Array(Hecate::AST::Node)
    [@left.as(Hecate::AST::Node), @right.as(Hecate::AST::Node)]
  end
  
  def clone : self
    TestAdd.new(@left.clone, @right.clone, @span)
  end
  
  def ==(other : self) : Bool
    super && @left == other.left && @right == other.right
  end
end

describe "Manual AST Node Implementation" do
  
  it "creates and uses AST nodes" do
    # Create a simple expression: 1 + 2
    left = TestIntLit.new(1, make_span(0, 1))
    right = TestIntLit.new(2, make_span(2, 3))
    add = TestAdd.new(left, right, make_span(0, 3))
    
    # Test basic properties
    add.left.as(TestIntLit).value.should eq(1)
    add.right.as(TestIntLit).value.should eq(2)
    
    # Test children
    children = add.children
    children.size.should eq(2)
    children[0].should be(left)
    children[1].should be(right)
    
    # Test cloning
    cloned = add.clone
    cloned.should eq(add)
    cloned.should_not be(add)
    cloned.left.should_not be(add.left)
    
    # Test equality
    add2 = TestAdd.new(
      TestIntLit.new(1, make_span(0, 1)),
      TestIntLit.new(2, make_span(2, 3)),
      make_span(0, 3)
    )
    add.should eq(add2)
  end
end