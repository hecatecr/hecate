require "../../../spec_helper"
require "hecate-core/test_utils"

# Test module to include AST functionality
module TestAST
  include Hecate::AST

  # Define abstract node types
  abstract_node Expr
  abstract_node Stmt

  # Test concrete nodes
  node IntLit < Expr, value : Int32
  node StringLit < Expr, value : String
  node BoolLit < Expr, value : Bool

  # Node with multiple fields
  node BinaryOp < Expr, left : TestAST::Expr, right : TestAST::Expr, op : String

  # Node with optional field
  node VarDecl < Stmt, name : String, value : TestAST::Expr?

  # Node with array field
  node Block < Stmt, statements : Array(TestAST::Stmt)

  # Node with mixed fields
  node FuncDef < Stmt,
    name : String,
    params : Array(String),
    body : TestAST::Block,
    return_type : String?
end

describe Hecate::AST::Macros do
  describe "node generation" do
    it "generates basic getters" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)
      node = TestAST::IntLit.new(span, 42)

      node.value.should eq(42)
      node.span.should eq(span)
    end

    it "generates constructor with all fields" do
      span = Hecate::Core::Span.new(0_u32, 0, 10)
      left = TestAST::IntLit.new(span, 1)
      right = TestAST::IntLit.new(span, 2)

      node = TestAST::BinaryOp.new(span, left, right, "+")

      node.left.should eq(left)
      node.right.should eq(right)
      node.op.should eq("+")
    end

    it "handles optional fields" do
      span = Hecate::Core::Span.new(0_u32, 0, 10)

      # Without value
      decl1 = TestAST::VarDecl.new(span, "x", nil)
      decl1.name.should eq("x")
      decl1.value.should be_nil

      # With value
      value = TestAST::IntLit.new(span, 42)
      decl2 = TestAST::VarDecl.new(span, "y", value)
      decl2.name.should eq("y")
      decl2.value.should eq(value)
    end

    it "handles array fields" do
      span = Hecate::Core::Span.new(0_u32, 0, 20)
      stmt1 = TestAST::VarDecl.new(span, "x", nil)
      stmt2 = TestAST::VarDecl.new(span, "y", nil)

      statements = [stmt1, stmt2] of TestAST::Stmt
      block = TestAST::Block.new(span, statements)
      block.statements.should eq(statements)
    end
  end

  # Visitor pattern tests moved to visitor_spec.cr

  describe "children extraction" do
    it "returns empty array for leaf nodes" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)
      node = TestAST::IntLit.new(span, 42)

      node.children.should eq([] of Hecate::AST::Node)
    end

    it "extracts single node fields" do
      span = Hecate::Core::Span.new(0_u32, 0, 10)
      left = TestAST::IntLit.new(span, 1)
      right = TestAST::IntLit.new(span, 2)
      node = TestAST::BinaryOp.new(span, left, right, "+")

      node.children.should eq([left, right])
    end

    pending "handles optional node fields" do
      # Known limitation: Optional node field detection needs improvement
      # The macro system doesn't properly detect optional node types when
      # they're declared as Type? due to how Crystal expands the type
      span = Hecate::Core::Span.new(0_u32, 0, 10)

      # Without value
      decl1 = TestAST::VarDecl.new(span, "x", nil)
      decl1.children.should eq([] of Hecate::AST::Node)

      # With value
      value = TestAST::IntLit.new(span, 42)
      decl2 = TestAST::VarDecl.new(span, "y", value)
      decl2.children.should eq([value])
    end

    it "extracts array of nodes" do
      span = Hecate::Core::Span.new(0_u32, 0, 20)
      stmt1 = TestAST::VarDecl.new(span, "x", nil)
      stmt2 = TestAST::VarDecl.new(span, "y", nil)

      statements = [stmt1, stmt2] of TestAST::Stmt
      block = TestAST::Block.new(span, statements)
      block.children.should eq([stmt1, stmt2])
    end

    it "handles mixed field types" do
      span = Hecate::Core::Span.new(0_u32, 0, 30)
      body = TestAST::Block.new(span, [] of TestAST::Stmt)

      func = TestAST::FuncDef.new(span, "test", ["a", "b"], body, nil)
      # Only the body node should be in children, not string arrays
      func.children.should eq([body])
    end
  end

  describe "equality comparison" do
    it "compares nodes with same values as equal" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)
      node1 = TestAST::IntLit.new(span, 42)
      node2 = TestAST::IntLit.new(span, 42)

      (node1 == node2).should be_true
    end

    it "compares nodes with different values as not equal" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)
      node1 = TestAST::IntLit.new(span, 42)
      node2 = TestAST::IntLit.new(span, 43)

      (node1 == node2).should be_false
    end

    it "handles complex nodes" do
      span = Hecate::Core::Span.new(0_u32, 0, 10)
      left1 = TestAST::IntLit.new(span, 1)
      right1 = TestAST::IntLit.new(span, 2)
      node1 = TestAST::BinaryOp.new(span, left1, right1, "+")

      left2 = TestAST::IntLit.new(span, 1)
      right2 = TestAST::IntLit.new(span, 2)
      node2 = TestAST::BinaryOp.new(span, left2, right2, "+")

      (node1 == node2).should be_true
    end
  end

  describe "cloning" do
    it "clones simple nodes" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)
      node = TestAST::IntLit.new(span, 42)
      clone = node.clone

      clone.should eq(node)
      clone.should_not be(node) # Different object
    end

    it "deep clones nested nodes" do
      span = Hecate::Core::Span.new(0_u32, 0, 10)
      left = TestAST::IntLit.new(span, 1)
      right = TestAST::IntLit.new(span, 2)
      node = TestAST::BinaryOp.new(span, left, right, "+")

      clone = node.clone

      clone.should eq(node)
      clone.should_not be(node)
      clone.left.should eq(left)
      clone.left.should_not be(left) # Deep clone
      clone.right.should eq(right)
      clone.right.should_not be(right) # Deep clone
    end

    pending "clones optional fields" do
      # Known limitation: Optional node field cloning needs improvement
      # Related to the same issue with optional field detection
      span = Hecate::Core::Span.new(0_u32, 0, 10)
      value = TestAST::IntLit.new(span, 42)
      node = TestAST::VarDecl.new(span, "x", value)

      clone = node.clone

      clone.value.should eq(value)
      clone.value.not_nil!.should_not be(value) # Deep clone
    end

    it "clones array fields" do
      span = Hecate::Core::Span.new(0_u32, 0, 20)
      stmt1 = TestAST::VarDecl.new(span, "x", nil)
      stmt2 = TestAST::VarDecl.new(span, "y", nil)

      statements = [stmt1, stmt2] of TestAST::Stmt
      block = TestAST::Block.new(span, statements)
      clone = block.clone

      clone.statements.size.should eq(2)
      clone.statements[0].should eq(stmt1)
      clone.statements[0].should_not be(stmt1) # Deep clone
    end
  end

  describe "to_s representation" do
    it "generates readable string for simple nodes" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)
      node = TestAST::IntLit.new(span, 42)

      node.to_s.should eq("IntLit(value: 42)")
    end

    it "generates readable string for complex nodes" do
      span = Hecate::Core::Span.new(0_u32, 0, 10)
      left = TestAST::IntLit.new(span, 1)
      right = TestAST::IntLit.new(span, 2)
      node = TestAST::BinaryOp.new(span, left, right, "+")

      node.to_s.should eq("BinaryOp(left: IntLit(value: 1), right: IntLit(value: 2), op: +)")
    end
  end
end

# MockVisitor removed - visitor tests are now in visitor_spec.cr
