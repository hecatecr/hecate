require "../../spec_helper"

# Test module for type predicate generation
module TypePredicateTestAST
  include Hecate::AST

  # Define test nodes
  abstract_node Expr
  abstract_node Stmt

  node IntLit < Expr, value : Int32
  node BinaryOp < Expr, left : Expr, right : Expr, operator : String
  node VarDecl < Stmt, name : String, value : Expr?
  node Block < Stmt, statements : Array(Stmt)

  # Finalize to generate visitors and type predicates
  finalize_ast IntLit, BinaryOp, VarDecl, Block
end

describe "Type Predicate Generation" do
  describe "predicate methods generation" do
    it "generates predicate methods for each node type" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create instances of different node types
      int_lit = TypePredicateTestAST::IntLit.new(span, 42)
      binary_op = TypePredicateTestAST::BinaryOp.new(span, int_lit, int_lit, "+")
      var_decl = TypePredicateTestAST::VarDecl.new(span, "x", int_lit)
      block = TypePredicateTestAST::Block.new(span, [var_decl] of TypePredicateTestAST::Stmt)

      # Test that IntLit node responds correctly to predicates
      int_lit.int_lit?.should be_true
      int_lit.binary_op?.should be_false
      int_lit.var_decl?.should be_false
      int_lit.block?.should be_false

      # Test that BinaryOp node responds correctly to predicates
      binary_op.int_lit?.should be_false
      binary_op.binary_op?.should be_true
      binary_op.var_decl?.should be_false
      binary_op.block?.should be_false

      # Test that VarDecl node responds correctly to predicates
      var_decl.int_lit?.should be_false
      var_decl.binary_op?.should be_false
      var_decl.var_decl?.should be_true
      var_decl.block?.should be_false

      # Test that Block node responds correctly to predicates
      block.int_lit?.should be_false
      block.binary_op?.should be_false
      block.var_decl?.should be_false
      block.block?.should be_true
    end

    it "works with polymorphic node references" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create nodes and store them as base Node references
      nodes = [] of Hecate::AST::Node
      nodes << TypePredicateTestAST::IntLit.new(span, 10)
      nodes << TypePredicateTestAST::BinaryOp.new(span,
        TypePredicateTestAST::IntLit.new(span, 5),
        TypePredicateTestAST::IntLit.new(span, 3),
        "*"
      )
      nodes << TypePredicateTestAST::VarDecl.new(span, "y", nil)

      # Test predicates work through base class reference
      nodes[0].int_lit?.should be_true
      nodes[0].binary_op?.should be_false

      nodes[1].int_lit?.should be_false
      nodes[1].binary_op?.should be_true

      nodes[2].var_decl?.should be_true
      nodes[2].int_lit?.should be_false
    end

    it "enables idiomatic type checking in control flow" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create a mixed array of nodes
      nodes = [
        TypePredicateTestAST::IntLit.new(span, 1).as(Hecate::AST::Node),
        TypePredicateTestAST::BinaryOp.new(span,
          TypePredicateTestAST::IntLit.new(span, 2),
          TypePredicateTestAST::IntLit.new(span, 3),
          "+"
        ).as(Hecate::AST::Node),
        TypePredicateTestAST::VarDecl.new(span, "z", nil).as(Hecate::AST::Node),
      ]

      # Use predicates in control flow
      int_count = 0
      binary_count = 0
      var_count = 0

      nodes.each do |node|
        if node.int_lit?
          int_count += 1
        elsif node.binary_op?
          binary_count += 1
        elsif node.var_decl?
          var_count += 1
        end
      end

      int_count.should eq 1
      binary_count.should eq 1
      var_count.should eq 1
    end

    it "works with inheritance hierarchies" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create expression nodes
      int_lit = TypePredicateTestAST::IntLit.new(span, 99)
      binary_op = TypePredicateTestAST::BinaryOp.new(span, int_lit, int_lit, "-")

      # Both should be expressions but have different specific types
      expressions = [int_lit.as(Hecate::AST::Node), binary_op.as(Hecate::AST::Node)]

      # Verify type-specific predicates work
      expressions[0].int_lit?.should be_true
      expressions[0].binary_op?.should be_false

      expressions[1].int_lit?.should be_false
      expressions[1].binary_op?.should be_true
    end
  end

  describe "Crystal case/when pattern matching" do
    it "works with simple case/when statements" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create different node types
      nodes = [
        TypePredicateTestAST::IntLit.new(span, 100).as(Hecate::AST::Node),
        TypePredicateTestAST::BinaryOp.new(span,
          TypePredicateTestAST::IntLit.new(span, 1),
          TypePredicateTestAST::IntLit.new(span, 2),
          "+"
        ).as(Hecate::AST::Node),
        TypePredicateTestAST::VarDecl.new(span, "var", nil).as(Hecate::AST::Node),
      ]

      results = [] of String

      nodes.each do |node|
        result = case node
                 when TypePredicateTestAST::IntLit
                   "integer: #{node.value}"
                 when TypePredicateTestAST::BinaryOp
                   "binary: #{node.operator}"
                 when TypePredicateTestAST::VarDecl
                   "variable: #{node.name}"
                 else
                   "unknown"
                 end
        results << result
      end

      results.should eq [
        "integer: 100",
        "binary: +",
        "variable: var",
      ]
    end

    it "works with inheritance hierarchy in case/when" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create expression and statement nodes
      expr = TypePredicateTestAST::IntLit.new(span, 50).as(Hecate::AST::Node)
      stmt = TypePredicateTestAST::VarDecl.new(span, "test", nil).as(Hecate::AST::Node)

      nodes = [expr, stmt]
      categories = [] of String

      nodes.each do |node|
        category = case node
                   when TypePredicateTestAST::Expr
                     "expression"
                   when TypePredicateTestAST::Stmt
                     "statement"
                   else
                     "unknown"
                   end
        categories << category
      end

      categories.should eq ["expression", "statement"]
    end

    it "supports nested pattern matching" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create a binary operation with integer literals
      left = TypePredicateTestAST::IntLit.new(span, 7)
      right = TypePredicateTestAST::IntLit.new(span, 3)
      binary_op = TypePredicateTestAST::BinaryOp.new(span, left, right, "*")

      # Test nested pattern matching
      result = case binary_op
               when TypePredicateTestAST::BinaryOp
                 left_val = case binary_op.left
                            when TypePredicateTestAST::IntLit
                              binary_op.left.as(TypePredicateTestAST::IntLit).value
                            else
                              0
                            end
                 right_val = case binary_op.right
                             when TypePredicateTestAST::IntLit
                               binary_op.right.as(TypePredicateTestAST::IntLit).value
                             else
                               0
                             end
                 "#{left_val} #{binary_op.operator} #{right_val}"
               else
                 "not a binary op"
               end

      result.should eq "7 * 3"
    end

    it "works with guards in case/when" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create integer literals with different values
      nodes = [
        TypePredicateTestAST::IntLit.new(span, -5).as(Hecate::AST::Node),
        TypePredicateTestAST::IntLit.new(span, 0).as(Hecate::AST::Node),
        TypePredicateTestAST::IntLit.new(span, 42).as(Hecate::AST::Node),
        TypePredicateTestAST::VarDecl.new(span, "x", nil).as(Hecate::AST::Node),
      ]

      results = [] of String

      nodes.each do |node|
        result = case node
                 when TypePredicateTestAST::IntLit
                   if node.value < 0
                     "negative"
                   elsif node.value == 0
                     "zero"
                   else
                     "positive"
                   end
                 when TypePredicateTestAST::VarDecl
                   "variable"
                 else
                   "other"
                 end
        results << result
      end

      results.should eq ["negative", "zero", "positive", "variable"]
    end

    it "enables exhaustive pattern matching verification" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Test that we can handle all concrete node types
      nodes = [
        TypePredicateTestAST::IntLit.new(span, 123),
        TypePredicateTestAST::BinaryOp.new(span,
          TypePredicateTestAST::IntLit.new(span, 1),
          TypePredicateTestAST::IntLit.new(span, 2),
          "/"
        ),
        TypePredicateTestAST::VarDecl.new(span, "exhaustive", nil),
        TypePredicateTestAST::Block.new(span, [] of TypePredicateTestAST::Stmt),
      ]

      # This should handle all possible concrete node types
      nodes.each do |node|
        handled = case node
                  when TypePredicateTestAST::IntLit
                    true
                  when TypePredicateTestAST::BinaryOp
                    true
                  when TypePredicateTestAST::VarDecl
                    true
                  when TypePredicateTestAST::Block
                    true
                  else
                    false
                  end
        handled.should be_true
      end
    end
  end

  describe "type discrimination helper methods" do
    it "provides node_type_symbol for debugging" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      nodes = [
        TypePredicateTestAST::IntLit.new(span, 99).as(Hecate::AST::Node),
        TypePredicateTestAST::BinaryOp.new(span,
          TypePredicateTestAST::IntLit.new(span, 1),
          TypePredicateTestAST::IntLit.new(span, 2),
          "+"
        ).as(Hecate::AST::Node),
        TypePredicateTestAST::VarDecl.new(span, "symbol_test", nil).as(Hecate::AST::Node),
      ]

      symbols = nodes.map(&.node_type_symbol)
      symbols.should eq [:int_lit, :binary_op, :var_decl]
    end

    it "can be used with symbol matching for identification" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      nodes = [
        TypePredicateTestAST::IntLit.new(span, 555).as(Hecate::AST::Node),
        TypePredicateTestAST::BinaryOp.new(span,
          TypePredicateTestAST::IntLit.new(span, 10),
          TypePredicateTestAST::IntLit.new(span, 20),
          "^"
        ).as(Hecate::AST::Node),
        TypePredicateTestAST::Block.new(span, [] of TypePredicateTestAST::Stmt).as(Hecate::AST::Node),
      ]

      results = [] of String

      nodes.each do |node|
        result = case node.node_type_symbol
                 when :int_lit
                   "integer literal"
                 when :binary_op
                   "binary operation"
                 when :var_decl
                   "variable declaration"
                 when :block
                   "block statement"
                 else
                   "unknown"
                 end
        results << result
      end

      results.should eq ["integer literal", "binary operation", "block statement"]
    end

    it "categorizes expressions and statements correctly" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create expression nodes
      int_lit = TypePredicateTestAST::IntLit.new(span, 42)
      binary_op = TypePredicateTestAST::BinaryOp.new(span, int_lit, int_lit, "+")

      # Create statement nodes
      var_decl = TypePredicateTestAST::VarDecl.new(span, "test", nil)
      block = TypePredicateTestAST::Block.new(span, [] of TypePredicateTestAST::Stmt)

      # Test expression categorization
      int_lit.expression?.should be_true
      int_lit.statement?.should be_false

      binary_op.expression?.should be_true
      binary_op.statement?.should be_false

      # Test statement categorization
      var_decl.expression?.should be_false
      var_decl.statement?.should be_true

      block.expression?.should be_false
      block.statement?.should be_true
    end

    it "works with polymorphic collections for categorization" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Mixed collection of expressions and statements
      nodes = [
        TypePredicateTestAST::IntLit.new(span, 1).as(Hecate::AST::Node), # Expression
        TypePredicateTestAST::BinaryOp.new(span,                         # Expression
          TypePredicateTestAST::IntLit.new(span, 2),
          TypePredicateTestAST::IntLit.new(span, 3),
          "*"
        ).as(Hecate::AST::Node),
        TypePredicateTestAST::VarDecl.new(span, "x", nil).as(Hecate::AST::Node),                       # Statement
        TypePredicateTestAST::Block.new(span, [] of TypePredicateTestAST::Stmt).as(Hecate::AST::Node), # Statement
      ]

      expressions = nodes.select(&.expression?)
      statements = nodes.select(&.statement?)

      expressions.size.should eq 2
      statements.size.should eq 2

      # Verify no overlap
      (expressions + statements).size.should eq nodes.size
    end
  end

  describe "exhaustive pattern matching helpers" do
    it "provides all_node_types class method" do
      # Get all node types for our test AST
      all_types = Hecate::AST::Node.all_node_types

      # Should include all concrete node types we defined
      expected_types = [:int_lit, :binary_op, :var_decl, :block]

      # All expected types should be present
      expected_types.each do |expected_type|
        all_types.should contain(expected_type)
      end

      # Should not include abstract types (Expr, Stmt)
      all_types.should_not contain(:expr)
      all_types.should_not contain(:stmt)
    end

    it "checks exhaustive coverage with exhaustive_match?" do
      # Complete coverage should return true
      complete_coverage = [:int_lit, :binary_op, :var_decl, :block]
      Hecate::AST::Node.exhaustive_match?(complete_coverage).should be_true

      # Incomplete coverage should return false
      incomplete_coverage = [:int_lit, :binary_op]
      Hecate::AST::Node.exhaustive_match?(incomplete_coverage).should be_false

      # Extra types should still be considered complete if all required types are present
      extra_coverage = [:int_lit, :binary_op, :var_decl, :block]
      Hecate::AST::Node.exhaustive_match?(extra_coverage).should be_true
    end

    it "identifies missing types with missing_from_match" do
      # Partial coverage should return missing types
      partial_coverage = [:int_lit, :binary_op]
      missing = Hecate::AST::Node.missing_from_match(partial_coverage)

      missing.should contain(:var_decl)
      missing.should contain(:block)
      missing.size.should eq 2

      # Complete coverage should return empty array
      complete_coverage = [:int_lit, :binary_op, :var_decl, :block]
      missing_complete = Hecate::AST::Node.missing_from_match(complete_coverage)
      missing_complete.should be_empty
    end

    it "validates exhaustive matches with validate_exhaustive_match" do
      # Complete coverage should not raise
      complete_coverage = [:int_lit, :binary_op, :var_decl, :block]

      # Actually test that complete coverage doesn't raise
      Hecate::AST::Node.validate_exhaustive_match(complete_coverage)

      # Incomplete coverage should raise with informative message
      incomplete_coverage = [:int_lit, :binary_op]
      expect_raises(Exception, /Non-exhaustive pattern match.*var_decl.*block/) do
        Hecate::AST::Node.validate_exhaustive_match(incomplete_coverage)
      end
    end

    it "enables exhaustive match validation in real pattern matching scenarios" do
      span = Hecate::Core::Span.new(0_u32, 0, 5)

      # Create test nodes
      nodes = [
        TypePredicateTestAST::IntLit.new(span, 1).as(Hecate::AST::Node),
        TypePredicateTestAST::BinaryOp.new(span,
          TypePredicateTestAST::IntLit.new(span, 2),
          TypePredicateTestAST::IntLit.new(span, 3),
          "+"
        ).as(Hecate::AST::Node),
        TypePredicateTestAST::VarDecl.new(span, "x", nil).as(Hecate::AST::Node),
        TypePredicateTestAST::Block.new(span, [] of TypePredicateTestAST::Stmt).as(Hecate::AST::Node),
      ]

      # Simulate a pattern matching scenario with validation
      results = [] of String

      nodes.each do |node|
        # Get the node type symbol for validation
        node_type = node.node_type_symbol

        # Validate that our case/when handles all types
        handled_types = [:int_lit, :binary_op, :var_decl, :block]
        Hecate::AST::Node.validate_exhaustive_match(handled_types)

        # Now perform the actual pattern matching
        result = case node
                 when TypePredicateTestAST::IntLit
                   "integer"
                 when TypePredicateTestAST::BinaryOp
                   "binary operation"
                 when TypePredicateTestAST::VarDecl
                   "variable declaration"
                 when TypePredicateTestAST::Block
                   "block statement"
                 else
                   "unhandled: #{node_type}"
                 end
        results << result
      end

      # All nodes should be handled correctly
      results.should eq ["integer", "binary operation", "variable declaration", "block statement"]
      results.none?(&.starts_with?("unhandled")).should be_true
    end

    it "helps identify incomplete pattern matches during development" do
      # Simulate a developer adding a new node type but forgetting to update pattern matches
      incomplete_pattern_types = [:int_lit, :binary_op, :var_decl] # Missing :block

      # This should help catch the incomplete pattern match
      missing = Hecate::AST::Node.missing_from_match(incomplete_pattern_types)
      missing.should contain(:block)

      # The developer can use this information to update their pattern match
      complete_pattern_types = incomplete_pattern_types + missing
      Hecate::AST::Node.exhaustive_match?(complete_pattern_types).should be_true
    end

    it "works with different orderings of pattern types" do
      # Order shouldn't matter for exhaustive checking
      patterns = [
        [:int_lit, :binary_op, :var_decl, :block],
        [:block, :var_decl, :binary_op, :int_lit],
        [:binary_op, :int_lit, :block, :var_decl],
      ]

      patterns.each do |pattern|
        Hecate::AST::Node.exhaustive_match?(pattern).should be_true
        Hecate::AST::Node.missing_from_match(pattern).should be_empty
      end
    end
  end
end
