require "../../spec_helper"

# Test module for visitor pattern generation
module VisitorTestAST
  include Hecate::AST
  
  # Define test nodes
  abstract_node Expr
  abstract_node Stmt
  
  node IntLit < Expr, value : Int32
  node Add < Expr, left : Expr, right : Expr  
  node VarDecl < Stmt, name : String, value : Expr?
  
  # Finalize to generate visitors
  finalize_ast IntLit, Add, VarDecl
end

# Visitor implementation for testing
class TestStringVisitor < VisitorTestAST::Visitor(String)
  def visit_int_lit(node : VisitorTestAST::IntLit) : String
    "IntLit(#{node.value})"
  end
  
  def visit_add(node : VisitorTestAST::Add) : String
    left = visit(node.left)
    right = visit(node.right)
    "Add(#{left}, #{right})"
  end
  
  def visit_var_decl(node : VisitorTestAST::VarDecl) : String
    value_str = node.value ? visit(node.value.not_nil!) : "nil"
    "VarDecl(#{node.name}, #{value_str})"
  end
end

# Transformer implementation for testing
class AddToMultiplyTransformer < VisitorTestAST::Transformer
  def visit_add(node : VisitorTestAST::Add) : Hecate::AST::Node
    # Transform Add to a multiplication (just for testing - changing left to right + right)
    right_value = node.right
    VisitorTestAST::Add.new(node.span, right_value, right_value)
  end
end

describe "Visitor Pattern Generation" do
  it "generates abstract visitor class with correct visit methods" do
    # Test that Visitor class exists and has the right methods
    visitor_class = VisitorTestAST::Visitor
    visitor_class.should_not be_nil
  end
  
  it "allows concrete visitor implementations" do
    span = Hecate::Core::Span.new(0_u32, 0, 5)
    
    # Create test nodes
    int_lit = VisitorTestAST::IntLit.new(span, 42)
    add_node = VisitorTestAST::Add.new(span, int_lit, VisitorTestAST::IntLit.new(span, 10))
    var_decl = VisitorTestAST::VarDecl.new(span, "x", add_node)
    
    visitor = TestStringVisitor.new
    
    # Test visitor functionality
    visitor.visit(int_lit).should eq "IntLit(42)"
    visitor.visit(add_node).should eq "Add(IntLit(42), IntLit(10))"
    visitor.visit(var_decl).should eq "VarDecl(x, Add(IntLit(42), IntLit(10)))"
  end
  
  it "generates transformer base class" do
    # Test that Transformer class exists
    transformer_class = VisitorTestAST::Transformer
    transformer_class.should_not be_nil
  end
  
  it "allows transformer implementations with default behavior" do
    span = Hecate::Core::Span.new(0_u32, 0, 5)
    
    # Create a simple expression
    int_lit = VisitorTestAST::IntLit.new(span, 5)
    add_node = VisitorTestAST::Add.new(span, int_lit, VisitorTestAST::IntLit.new(span, 3))
    
    transformer = AddToMultiplyTransformer.new
    result = transformer.visit(add_node)
    
    # Should transform Add(5, 3) to Add(3, 3)
    result.should be_a(VisitorTestAST::Add)
    transformed = result.as(VisitorTestAST::Add)
    
    # Both left and right should be the original right operand
    transformed.left.should be_a(VisitorTestAST::IntLit)
    transformed.right.should be_a(VisitorTestAST::IntLit)
    
    transformed.left.as(VisitorTestAST::IntLit).value.should eq 3
    transformed.right.as(VisitorTestAST::IntLit).value.should eq 3
  end
  
  it "handles optional fields correctly" do
    span = Hecate::Core::Span.new(0_u32, 0, 5)
    
    # Test with nil value
    var_decl_nil = VisitorTestAST::VarDecl.new(span, "y", nil)
    visitor = TestStringVisitor.new
    visitor.visit(var_decl_nil).should eq "VarDecl(y, nil)"
    
    # Test with actual value
    int_lit = VisitorTestAST::IntLit.new(span, 100)
    var_decl_with_value = VisitorTestAST::VarDecl.new(span, "z", int_lit)
    visitor.visit(var_decl_with_value).should eq "VarDecl(z, IntLit(100))"
  end
end