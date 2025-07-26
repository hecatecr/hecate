require "../../spec_helper"

# Comprehensive integration tests for the Builder Pattern DSL
# These tests verify that builder-constructed ASTs are equivalent to manually constructed ones

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Complete language AST for integration testing
module IntegrationLang
  include Hecate::AST
  
  abstract_node Expr
  abstract_node Stmt
  
  # Expression nodes
  node IntLit < Expr, value : Int32
  node StringLit < Expr, value : String
  node Identifier < Expr, name : String
  node BinaryOp < Expr, op : String, left : Expr, right : Expr
  node UnaryOp < Expr, op : String, operand : Expr
  node ConditionalExpr < Expr, condition : Expr, true_expr : Expr, false_expr : Expr
  
  # Statement nodes
  node VarDecl < Stmt, name : String, value : Expr?
  node Assignment < Stmt, name : String, value : Expr
  node IfStmt < Stmt, condition : Expr, then_stmt : Stmt, else_stmt : Stmt?
  node WhileStmt < Stmt, condition : Expr, body : Stmt
  node BlockStmt < Stmt, statements : Array(Stmt)
  node ExprStmt < Stmt, expr : Expr
  
  finalize_ast IntLit, StringLit, Identifier, BinaryOp, UnaryOp, ConditionalExpr,
               VarDecl, Assignment, IfStmt, WhileStmt, BlockStmt, ExprStmt
  
  # Generate builder methods
  generate_builder IntLit, value : Int32
  generate_builder StringLit, value : String
  generate_builder Identifier, name : String
  generate_builder BinaryOp, op : String, left : Expr, right : Expr
  generate_builder UnaryOp, op : String, operand : Expr
  generate_builder ConditionalExpr, condition : Expr, true_expr : Expr, false_expr : Expr
  generate_builder VarDecl, name : String, value : Expr?
  generate_builder Assignment, name : String, value : Expr
  generate_builder IfStmt, condition : Expr, then_stmt : Stmt, else_stmt : Stmt?
  generate_builder WhileStmt, condition : Expr, body : Stmt
  generate_builder BlockStmt, statements : Array(Stmt)
  generate_builder ExprStmt, expr : Expr
  
  add_builder_conveniences
end

describe "Builder Pattern Integration Tests" do
  describe "Expression Construction" do
    it "builds simple expressions identically to manual construction" do
      span = make_span()
      
      # Manual: 1 + 2
      manual = IntegrationLang::BinaryOp.new(span, "+", 
        IntegrationLang::IntLit.new(span, 1),
        IntegrationLang::IntLit.new(span, 2)
      )
      
      # Builder: 1 + 2
      builder = IntegrationLang::Builder.binary_op("+",
        IntegrationLang::Builder.int_lit(1),
        IntegrationLang::Builder.int_lit(2)
      )
      
      # Verify structure equivalence
      manual.op.should eq(builder.op)
      manual.left.as(IntegrationLang::IntLit).value.should eq(builder.left.as(IntegrationLang::IntLit).value)
      manual.right.as(IntegrationLang::IntLit).value.should eq(builder.right.as(IntegrationLang::IntLit).value)
    end

    it "builds nested expressions correctly" do
      span = make_span()
      
      # Manual: (a + b) * (c - d)
      manual = IntegrationLang::BinaryOp.new(span, "*",
        IntegrationLang::BinaryOp.new(span, "+",
          IntegrationLang::Identifier.new(span, "a"),
          IntegrationLang::Identifier.new(span, "b")
        ),
        IntegrationLang::BinaryOp.new(span, "-",
          IntegrationLang::Identifier.new(span, "c"),
          IntegrationLang::Identifier.new(span, "d")
        )
      )
      
      # Builder: (a + b) * (c - d)
      builder = IntegrationLang::Builder.build do
        binary_op("*",
          binary_op("+", identifier("a"), identifier("b")),
          binary_op("-", identifier("c"), identifier("d"))
        )
      end
      
      # Verify structure
      builder.should be_a(IntegrationLang::BinaryOp)
      builder.op.should eq("*")
      
      left = builder.left.as(IntegrationLang::BinaryOp)
      left.op.should eq("+")
      left.left.as(IntegrationLang::Identifier).name.should eq("a")
      left.right.as(IntegrationLang::Identifier).name.should eq("b")
      
      right = builder.right.as(IntegrationLang::BinaryOp)
      right.op.should eq("-")
      right.left.as(IntegrationLang::Identifier).name.should eq("c")
      right.right.as(IntegrationLang::Identifier).name.should eq("d")
    end

    it "builds unary expressions with proper nesting" do
      span = make_span()
      
      # Manual: -(x + 1)
      manual = IntegrationLang::UnaryOp.new(span, "-",
        IntegrationLang::BinaryOp.new(span, "+",
          IntegrationLang::Identifier.new(span, "x"),
          IntegrationLang::IntLit.new(span, 1)
        )
      )
      
      # Builder: -(x + 1)
      builder = IntegrationLang::Builder.build do
        unary_op("-", binary_op("+", identifier("x"), int_lit(1)))
      end
      
      builder.should be_a(IntegrationLang::UnaryOp)
      builder.op.should eq("-")
      
      inner = builder.operand.as(IntegrationLang::BinaryOp)
      inner.op.should eq("+")
      inner.left.as(IntegrationLang::Identifier).name.should eq("x")
      inner.right.as(IntegrationLang::IntLit).value.should eq(1)
    end

    it "builds conditional expressions" do
      # Manual: condition ? true_val : false_val
      manual = IntegrationLang::ConditionalExpr.new(make_span(),
        IntegrationLang::Identifier.new(make_span(), "condition"),
        IntegrationLang::StringLit.new(make_span(), "true_val"),
        IntegrationLang::StringLit.new(make_span(), "false_val")
      )
      
      # Builder: condition ? true_val : false_val
      builder = IntegrationLang::Builder.conditional_expr(
        IntegrationLang::Builder.identifier("condition"),
        IntegrationLang::Builder.string_lit("true_val"),
        IntegrationLang::Builder.string_lit("false_val")
      )
      
      builder.should be_a(IntegrationLang::ConditionalExpr)
      builder.condition.as(IntegrationLang::Identifier).name.should eq("condition")
      builder.true_expr.as(IntegrationLang::StringLit).value.should eq("true_val")
      builder.false_expr.as(IntegrationLang::StringLit).value.should eq("false_val")
    end
  end

  describe "Statement Construction" do
    it "builds variable declarations with optional values" do
      span = make_span()
      
      # Manual: let x = 42
      manual_with_value = IntegrationLang::VarDecl.new(span, "x", 
        IntegrationLang::IntLit.new(span, 42))
      
      # Builder: let x = 42
      builder_with_value = IntegrationLang::Builder.var_decl("x", 
        IntegrationLang::Builder.some(IntegrationLang::Builder.int_lit(42)))
      
      builder_with_value.name.should eq("x")
      builder_with_value.value.should_not be_nil
      builder_with_value.value.not_nil!.as(IntegrationLang::IntLit).value.should eq(42)
      
      # Manual: let y (no value)
      manual_no_value = IntegrationLang::VarDecl.new(span, "y", nil)
      
      # Builder: let y (no value)
      builder_no_value = IntegrationLang::Builder.var_decl("y", 
        IntegrationLang::Builder.none)
      
      builder_no_value.name.should eq("y")
      builder_no_value.value.should be_nil
    end

    it "builds if statements with optional else clause" do
      span = make_span()
      
      # Manual: if (x > 0) y = 1 else y = 0
      manual = IntegrationLang::IfStmt.new(span,
        IntegrationLang::BinaryOp.new(span, ">",
          IntegrationLang::Identifier.new(span, "x"),
          IntegrationLang::IntLit.new(span, 0)
        ),
        IntegrationLang::Assignment.new(span, "y", IntegrationLang::IntLit.new(span, 1)),
        IntegrationLang::Assignment.new(span, "y", IntegrationLang::IntLit.new(span, 0))
      )
      
      # Builder: if (x > 0) y = 1 else y = 0
      builder = IntegrationLang::Builder.build do
        if_stmt(
          binary_op(">", identifier("x"), int_lit(0)),
          assignment("y", int_lit(1)),
          some(assignment("y", int_lit(0)))
        )
      end
      
      builder.should be_a(IntegrationLang::IfStmt)
      
      condition = builder.condition.as(IntegrationLang::BinaryOp)
      condition.op.should eq(">")
      condition.left.as(IntegrationLang::Identifier).name.should eq("x")
      condition.right.as(IntegrationLang::IntLit).value.should eq(0)
      
      then_stmt = builder.then_stmt.as(IntegrationLang::Assignment)
      then_stmt.name.should eq("y")
      then_stmt.value.as(IntegrationLang::IntLit).value.should eq(1)
      
      else_stmt = builder.else_stmt.not_nil!.as(IntegrationLang::Assignment)
      else_stmt.name.should eq("y")
      else_stmt.value.as(IntegrationLang::IntLit).value.should eq(0)
    end

    it "builds block statements with multiple statements" do
      # Builder: { x = 1; y = 2; z = x + y; }
      builder = IntegrationLang::Builder.build do
        block_stmt(list(
          assignment("x", int_lit(1)).as(IntegrationLang::Stmt),
          assignment("y", int_lit(2)).as(IntegrationLang::Stmt),
          assignment("z", binary_op("+", identifier("x"), identifier("y"))).as(IntegrationLang::Stmt)
        ))
      end
      
      builder.should be_a(IntegrationLang::BlockStmt)
      builder.statements.size.should eq(3)
      
      stmt1 = builder.statements[0].as(IntegrationLang::Assignment)
      stmt1.name.should eq("x")
      stmt1.value.as(IntegrationLang::IntLit).value.should eq(1)
      
      stmt2 = builder.statements[1].as(IntegrationLang::Assignment)
      stmt2.name.should eq("y")
      stmt2.value.as(IntegrationLang::IntLit).value.should eq(2)
      
      stmt3 = builder.statements[2].as(IntegrationLang::Assignment)
      stmt3.name.should eq("z")
      expr = stmt3.value.as(IntegrationLang::BinaryOp)
      expr.op.should eq("+")
      expr.left.as(IntegrationLang::Identifier).name.should eq("x")
      expr.right.as(IntegrationLang::Identifier).name.should eq("y")
    end
  end

  describe "Advanced Features Integration" do
    it "uses span_for to calculate proper spans for nested structures" do
      # Create child nodes with specific spans
      left_child = IntegrationLang::Builder.int_lit(1, make_span(0, 1))
      right_child = IntegrationLang::Builder.int_lit(2, make_span(4, 5))
      
      # Calculate encompassing span
      parent_span = IntegrationLang::Builder.span_for(left_child, right_child)
      
      # Create parent with calculated span
      parent = IntegrationLang::Builder.binary_op("+", left_child, right_child, parent_span)
      
      parent.span.start_byte.should eq(0)
      parent.span.end_byte.should eq(5)
      parent.span.source_id.should eq(0_u32)
    end

    it "integrates all convenience methods in complex construction" do
      # Build a complex structure using all convenience methods
      result = IntegrationLang::Builder.build do
        block_stmt(list(
          var_decl("items", some(string_lit("initial"))),
          var_decl("count", none),
          if_stmt(
            binary_op("!=", identifier("items"), identifier("null")),
            assignment("count", int_lit(1)),
            none
          )
        ))
      end
      
      result.should be_a(IntegrationLang::BlockStmt)
      result.statements.size.should eq(3)
      
      # Check first statement (var with value)
      var1 = result.statements[0].as(IntegrationLang::VarDecl)
      var1.name.should eq("items")
      var1.value.should_not be_nil
      
      # Check second statement (var without value)
      var2 = result.statements[1].as(IntegrationLang::VarDecl)
      var2.name.should eq("count")
      var2.value.should be_nil
      
      # Check if statement (with no else)
      if_stmt = result.statements[2].as(IntegrationLang::IfStmt)
      if_stmt.condition.should be_a(IntegrationLang::BinaryOp)
      if_stmt.then_stmt.should be_a(IntegrationLang::Assignment)
      if_stmt.else_stmt.should be_nil
    end

    it "preserves type safety throughout complex construction" do
      # This test verifies that all type constraints work correctly
      complex_expr = IntegrationLang::Builder.build do
        conditional_expr(
          binary_op("&&",
            binary_op(">", identifier("x"), int_lit(0)),
            unary_op("!", identifier("flag"))
          ),
          binary_op("+", identifier("a"), int_lit(10)),
          binary_op("-", identifier("b"), int_lit(5))
        )
      end
      
      # Verify the entire structure is properly typed
      complex_expr.should be_a(IntegrationLang::ConditionalExpr)
      
      condition = complex_expr.condition.as(IntegrationLang::BinaryOp)
      condition.op.should eq("&&")
      condition.left.should be_a(IntegrationLang::BinaryOp)
      condition.right.should be_a(IntegrationLang::UnaryOp)
      
      true_branch = complex_expr.true_expr.as(IntegrationLang::BinaryOp)
      true_branch.op.should eq("+")
      
      false_branch = complex_expr.false_expr.as(IntegrationLang::BinaryOp)
      false_branch.op.should eq("-")
    end
  end

  describe "Performance and Memory" do
    it "efficiently builds large AST structures" do
      # Build a large nested structure to test performance
      large_expr = IntegrationLang::Builder.build do
        # Create a deeply nested binary operation tree
        # This simulates: ((((1 + 2) + 3) + 4) + ... + 100)
        base = int_lit(1)
        (2..100).reduce(base) do |acc, i|
          binary_op("+", acc, int_lit(i))
        end
      end
      
      # Verify the structure was built correctly
      large_expr.should be_a(IntegrationLang::BinaryOp)
      
      # Count the depth of nesting - simple check for deep structure
      current = large_expr
      depth = 0
      while current.is_a?(IntegrationLang::BinaryOp) && current.left.is_a?(IntegrationLang::BinaryOp)
        depth += 1
        current = current.left.as(IntegrationLang::BinaryOp)
        break if depth > 100  # Prevent infinite loop
      end
      
      depth.should be > 90  # Should be a deep tree
    end
  end
end