require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Create test AST nodes with manual validation methods
abstract class TestExpr < Hecate::AST::Node
end

class TestIntLit < TestExpr
  getter value : Int32

  def initialize(@value : Int32, span : Hecate::Core::Span)
    super(span)
  end

  def accept(visitor)
    visitor.visit_test_int_lit(self) if visitor.responds_to?(:visit_test_int_lit)
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

class TestPositiveInt < TestExpr
  getter value : Int32

  def initialize(@value : Int32, span : Hecate::Core::Span)
    super(span)
  end

  def accept(visitor)
    visitor.visit_test_positive_int(self) if visitor.responds_to?(:visit_test_positive_int)
  end

  def children : Array(Hecate::AST::Node)
    [] of Hecate::AST::Node
  end

  def clone : self
    TestPositiveInt.new(@value, @span)
  end

  def ==(other : self) : Bool
    super && @value == other.value
  end

  # This node has validation rules
  def validate : Array(Hecate::Core::Diagnostic)
    errors = [] of Hecate::Core::Diagnostic

    if @value < 0
      errors << Hecate::Core.error("Value must be positive").primary(@span, "here").build
    end

    if @value > 1000000
      errors << Hecate::Core.warning("Very large integer").primary(@span, "here").build
    end

    errors
  end
end

class TestAdd < TestExpr
  getter left : TestExpr
  getter right : TestExpr

  def initialize(@left : TestExpr, @right : TestExpr, span : Hecate::Core::Span)
    super(span)
  end

  def accept(visitor)
    visitor.visit_test_add(self) if visitor.responds_to?(:visit_test_add)
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

  # This node has validation rules for its children
  def validate : Array(Hecate::Core::Diagnostic)
    errors = [] of Hecate::Core::Diagnostic

    # Check for redundant operations
    # Check left operand
    if @left.is_a?(TestIntLit)
      left_int = @left.as(TestIntLit)
      if left_int.value == 0
        errors << Hecate::Core.hint("Adding zero is redundant").primary(@left.span, "here").build
      end
    elsif @left.is_a?(TestPositiveInt)
      left_pos = @left.as(TestPositiveInt)
      if left_pos.value == 0
        errors << Hecate::Core.hint("Adding zero is redundant").primary(@left.span, "here").build
      end
    end

    # Check right operand
    if @right.is_a?(TestIntLit)
      right_int = @right.as(TestIntLit)
      if right_int.value == 0
        errors << Hecate::Core.hint("Adding zero is redundant").primary(@right.span, "here").build
      end
    elsif @right.is_a?(TestPositiveInt)
      right_pos = @right.as(TestPositiveInt)
      if right_pos.value == 0
        errors << Hecate::Core.hint("Adding zero is redundant").primary(@right.span, "here").build
      end
    end

    errors
  end
end

describe "Hecate::AST::ASTValidator" do
  it "validates nodes without validation methods" do
    validator = Hecate::AST::ASTValidator.new
    node = TestIntLit.new(42, make_span())

    validator.visit(node)

    validator.valid?.should be_true
    validator.errors.should be_empty
  end

  it "validates nodes with validation methods" do
    validator = Hecate::AST::ASTValidator.new

    # Valid positive integer
    valid_node = TestPositiveInt.new(42, make_span())
    validator.visit(valid_node)
    validator.valid?.should be_true
    validator.errors.should be_empty

    # Clear and test invalid
    validator.clear
    invalid_node = TestPositiveInt.new(-5, make_span())
    validator.visit(invalid_node)

    validator.valid?.should be_false
    validator.error_count.should eq(1)
    validator.errors.first.message.should contain("must be positive")
  end

  it "collects validation errors from nested nodes" do
    validator = Hecate::AST::ASTValidator.new

    # Create an AST: Add(PositiveInt(-1), IntLit(0))
    left = TestPositiveInt.new(-1, make_span(0, 2)) # Error: negative
    right = TestIntLit.new(0, make_span(3, 4))      # No validation
    add = TestAdd.new(left, right, make_span(0, 4)) # Should check for hints about adding zero

    validator.visit(add)

    validator.valid?.should be_false
    validator.error_count.should eq(1) # From negative value
    validator.hint_count.should eq(1)  # From adding zero
  end

  it "categorizes diagnostics by level" do
    validator = Hecate::AST::ASTValidator.new

    # Create nodes with different diagnostic levels
    large_positive = TestPositiveInt.new(2000000, make_span()) # Warning: large
    negative = TestPositiveInt.new(-5, make_span())            # Error: negative
    zero_add = TestAdd.new(
      TestIntLit.new(0, make_span(0, 1)),
      TestIntLit.new(5, make_span(2, 3)),
      make_span(0, 3)
    ) # Note: adding zero

    validator.visit(large_positive)
    validator.visit(negative)
    validator.visit(zero_add)

    validator.error_count.should eq(1)   # negative value
    validator.warning_count.should eq(1) # large value
    validator.hint_count.should eq(1)    # adding zero

    validator.errors_only.first.message.should contain("must be positive")
    validator.warnings_only.first.message.should contain("large integer")
    validator.hints_only.first.message.should contain("redundant")
  end

  it "provides validation summary" do
    validator = Hecate::AST::ASTValidator.new

    # No errors
    validator.summary.should eq("Validation passed: no errors found")

    # Add some errors
    negative = TestPositiveInt.new(-5, make_span())
    validator.visit(negative)

    validator.summary.should contain("Validation failed")
    validator.summary.should contain("1 errors")
  end

  it "handles deeply nested AST structures" do
    validator = Hecate::AST::ASTValidator.new

    # Create a nested structure: Add(Add(PositiveInt(-1), IntLit(0)), PositiveInt(1000001))
    inner_left = TestPositiveInt.new(-1, make_span(0, 2))             # Error
    inner_right = TestIntLit.new(0, make_span(3, 4))                  # No validation
    inner_add = TestAdd.new(inner_left, inner_right, make_span(0, 4)) # Note

    outer_right = TestPositiveInt.new(1000001, make_span(5, 12)) # Warning
    outer_add = TestAdd.new(inner_add, outer_right, make_span(0, 12))

    validator.visit(outer_add)

    validator.error_count.should eq(1)   # negative value
    validator.warning_count.should eq(1) # large value
    validator.hint_count.should eq(1)    # adding zero
  end

  it "can be reused with clear method" do
    validator = Hecate::AST::ASTValidator.new

    # First validation
    invalid_node = TestPositiveInt.new(-5, make_span())
    validator.visit(invalid_node)
    validator.valid?.should be_false

    # Clear and validate something else
    validator.clear
    validator.valid?.should be_true
    validator.errors.should be_empty

    valid_node = TestPositiveInt.new(42, make_span())
    validator.visit(valid_node)
    validator.valid?.should be_true
  end
end
