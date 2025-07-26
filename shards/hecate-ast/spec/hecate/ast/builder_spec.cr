require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Test builder pattern foundation
describe "Hecate::AST::Builder" do
  it "provides DEFAULT_SPAN constant" do
    Hecate::AST::Builder::DEFAULT_SPAN.should be_a(Hecate::Core::Span)
    Hecate::AST::Builder::DEFAULT_SPAN.start_byte.should eq(0)
    Hecate::AST::Builder::DEFAULT_SPAN.end_byte.should eq(0)
  end

  it "has build method that can be called" do
    # Just test that the method exists and can be called
    result = nil
    Hecate::AST::Builder.build do
      result = "inside block"
    end
    result.should eq("inside block")
  end
end

# Example of how to create a builder for a specific AST
module TestBuilderAST
  include Hecate::AST

  abstract_node Expr
  node IntLit < Expr, value : Int32
  node Add < Expr, left : Expr, right : Expr

  finalize_ast IntLit, Add

  # Manual builder implementation (what users would create)
  module Builder
    extend self

    DEFAULT_SPAN = ::Hecate::Core::Span.new(0_u32, 0, 0)

    def int_lit(value : Int32, span = DEFAULT_SPAN)
      IntLit.new(span, value)
    end

    def add(left : Expr, right : Expr, span = DEFAULT_SPAN)
      Add.new(span, left, right)
    end

    def build(&block)
      with self yield
    end
  end
end

# Example of auto-generated builder using the generate_builders macro
module AutoBuilderAST
  include Hecate::AST

  abstract_node Expr
  node IntLit < Expr, value : Int32
  node Add < Expr, left : Expr, right : Expr
  node VarRef < Expr, name : String

  finalize_ast IntLit, Add, VarRef

  # Generate builder methods for each node type
  generate_builder IntLit, value : Int32
  generate_builder Add, left : Expr, right : Expr
  generate_builder VarRef, name : String
end

describe "Auto-generated Builder Pattern" do
  it "generates builder methods automatically" do
    # Test that the builder methods exist and work
    ast = AutoBuilderAST::Builder.build do
      add(int_lit(1), var_ref("x"))
    end

    ast.should be_a(AutoBuilderAST::Add)
    ast.left.as(AutoBuilderAST::IntLit).value.should eq(1)
    ast.right.as(AutoBuilderAST::VarRef).name.should eq("x")
  end

  it "generates methods with underscore names" do
    # Test method naming convention
    node = AutoBuilderAST::Builder.int_lit(42)
    node.should be_a(AutoBuilderAST::IntLit)
    node.value.should eq(42)

    var = AutoBuilderAST::Builder.var_ref("test")
    var.should be_a(AutoBuilderAST::VarRef)
    var.name.should eq("test")
  end

  it "uses default span when not provided" do
    node = AutoBuilderAST::Builder.int_lit(42)
    node.span.should eq(AutoBuilderAST::Builder::DEFAULT_SPAN)
  end

  it "accepts custom span when provided" do
    custom_span = make_span(10, 20)
    node = AutoBuilderAST::Builder.int_lit(42, custom_span)
    node.span.should eq(custom_span)
  end
end

describe "Manual Builder Pattern Example" do
  it "creates nodes using builder methods" do
    # Method-based construction
    left = TestBuilderAST::Builder.int_lit(1)
    right = TestBuilderAST::Builder.int_lit(2)
    add = TestBuilderAST::Builder.add(left, right)

    add.should be_a(TestBuilderAST::Add)
    add.left.as(TestBuilderAST::IntLit).value.should eq(1)
    add.right.as(TestBuilderAST::IntLit).value.should eq(2)
  end

  it "supports block-based DSL construction" do
    # Block-based construction
    ast = TestBuilderAST::Builder.build do
      add(int_lit(1), int_lit(2))
    end

    ast.should be_a(TestBuilderAST::Add)
    ast.left.as(TestBuilderAST::IntLit).value.should eq(1)
    ast.right.as(TestBuilderAST::IntLit).value.should eq(2)
  end

  it "uses default spans when not specified" do
    node = TestBuilderAST::Builder.int_lit(42)
    node.span.should eq(TestBuilderAST::Builder::DEFAULT_SPAN)
  end

  it "accepts custom spans when provided" do
    custom_span = make_span(5, 10)
    node = TestBuilderAST::Builder.int_lit(42, custom_span)
    node.span.should eq(custom_span)
  end
end

# Example using the convenience generate_builders block syntax
module ConvenienceBuilderAST
  include Hecate::AST

  abstract_node Stmt
  abstract_node Expr
  node IntLit < Expr, value : Int32
  node BinOp < Expr, op : String, left : Expr, right : Expr
  node VarDecl < Stmt, name : String, value : Expr?

  finalize_ast IntLit, BinOp, VarDecl

  # Use individual generate_builder calls
  generate_builder IntLit, value : Int32
  generate_builder BinOp, op : String, left : Expr, right : Expr
  generate_builder VarDecl, name : String, value : Expr?
end

describe "Individual Builder Generation" do
  it "generates builders for multiple node types" do
    # Test complex nested construction
    ast = ConvenienceBuilderAST::Builder.build do
      var_decl("x", bin_op("+", int_lit(1), int_lit(2)))
    end

    ast.should be_a(ConvenienceBuilderAST::VarDecl)
    ast.name.should eq("x")

    value = ast.value.not_nil!
    value.should be_a(ConvenienceBuilderAST::BinOp)
    value.as(ConvenienceBuilderAST::BinOp).op.should eq("+")
  end

  it "handles optional fields correctly" do
    # Test optional field with nil
    decl = ConvenienceBuilderAST::Builder.var_decl("y", nil)
    decl.name.should eq("y")
    decl.value.should be_nil

    # Test optional field with value
    decl2 = ConvenienceBuilderAST::Builder.var_decl("z", ConvenienceBuilderAST::Builder.int_lit(42))
    decl2.name.should eq("z")
    decl2.value.should_not be_nil
  end

  it "demonstrates ergonomic AST construction" do
    # Show how much cleaner this is compared to manual construction
    manual_ast = ConvenienceBuilderAST::VarDecl.new(
      make_span(),
      "result",
      ConvenienceBuilderAST::BinOp.new(
        make_span(),
        "*",
        ConvenienceBuilderAST::IntLit.new(make_span(), 5),
        ConvenienceBuilderAST::IntLit.new(make_span(), 10)
      )
    )

    builder_ast = ConvenienceBuilderAST::Builder.var_decl(
      "result",
      ConvenienceBuilderAST::Builder.bin_op("*",
        ConvenienceBuilderAST::Builder.int_lit(5),
        ConvenienceBuilderAST::Builder.int_lit(10)
      )
    )

    # Both should create equivalent structures (ignoring spans)
    manual_ast.name.should eq(builder_ast.name)
    manual_ast.value.class.should eq(builder_ast.value.class)
  end
end

# Test advanced builder features
module AdvancedBuilderAST
  include Hecate::AST

  abstract_node Expr
  node IntLit < Expr, value : Int32
  node BinOp < Expr, op : String, left : Expr, right : Expr

  finalize_ast IntLit, BinOp

  generate_builder IntLit, value : Int32
  generate_builder BinOp, op : String, left : Expr, right : Expr

  add_builder_conveniences
end

describe "Advanced Builder Features" do
  it "provides span_for helper method" do
    left = AdvancedBuilderAST::Builder.int_lit(1, make_span(10, 15))
    right = AdvancedBuilderAST::Builder.int_lit(2, make_span(20, 25))

    span = AdvancedBuilderAST::Builder.span_for(left, right)
    span.start_byte.should eq(10)
    span.end_byte.should eq(25)
  end

  it "provides convenience methods for optional values" do
    # Test some/none helpers
    some_value = AdvancedBuilderAST::Builder.some(AdvancedBuilderAST::Builder.int_lit(42))
    some_value.should_not be_nil
    some_value.not_nil!.should be_a(AdvancedBuilderAST::IntLit)

    none_value = AdvancedBuilderAST::Builder.none
    none_value.should be_nil
  end

  it "provides convenience methods for lists" do
    stmt1 = AdvancedBuilderAST::Builder.int_lit(1)
    stmt2 = AdvancedBuilderAST::Builder.int_lit(2)
    stmt3 = AdvancedBuilderAST::Builder.int_lit(3)

    list = AdvancedBuilderAST::Builder.list(stmt1, stmt2, stmt3)
    list.size.should eq(3)
    list.all?(&.is_a?(Hecate::AST::Node)).should be_true
  end

  it "works with complex nested structures" do
    # Test deeply nested construction
    ast = AdvancedBuilderAST::Builder.build do
      bin_op("+",
        bin_op("*", int_lit(1), int_lit(2)),
        int_lit(3)
      )
    end

    ast.should be_a(AdvancedBuilderAST::BinOp)
    ast.op.should eq("+")
    ast.left.should be_a(AdvancedBuilderAST::BinOp)
    ast.right.should be_a(AdvancedBuilderAST::IntLit)
  end

  it "demonstrates span propagation with span_for" do
    # Create child nodes with specific spans
    left = AdvancedBuilderAST::Builder.int_lit(1, make_span(0, 5))
    right = AdvancedBuilderAST::Builder.int_lit(2, make_span(10, 15))

    # Calculate encompassing span
    encompassing_span = AdvancedBuilderAST::Builder.span_for(left, right)

    # Create parent with calculated span
    parent = AdvancedBuilderAST::Builder.bin_op("+", left, right, encompassing_span)

    parent.span.start_byte.should eq(0)
    parent.span.end_byte.should eq(15)
  end
end
