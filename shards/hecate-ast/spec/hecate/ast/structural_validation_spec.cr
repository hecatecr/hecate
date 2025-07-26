require "../../spec_helper"

def make_span(start_byte : Int32 = 0, end_byte : Int32 = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

# Simple test node that can hold any AST nodes as children
class StructuralTestNode < Hecate::AST::Node
  getter child_nodes : Array(Hecate::AST::Node)
  
  def initialize(span : Hecate::Core::Span)
    super(span)
    @child_nodes = [] of Hecate::AST::Node
  end
  
  def add_child(node : Hecate::AST::Node)
    @child_nodes << node
  end
  
  def accept(visitor)
    visitor.visit(self) if visitor.responds_to?(:visit)
  end
  
  def children : Array(Hecate::AST::Node)
    @child_nodes
  end
  
  def clone : self
    # For testing, we don't need proper cloning
    self
  end
  
  def ==(other : self) : Bool
    # Simple object identity comparison to avoid infinite recursion in cycles
    self.object_id == other.object_id
  end
end

# Test AST modules for validation
module StructuralTestAST
  include Hecate::AST
  
  abstract_node Expr
  
  node PositiveInt < Expr, value : Int32 do
    if value < 0
      errors << error("Value must be positive", span).build
    end
  end
  
  finalize_ast PositiveInt
end

module SeverityTestAST
  include Hecate::AST
  
  abstract_node Expr
  
  node TestNode < Expr, value : Int32 do
    if value < 0
      errors << error("Negative value", span).build
    end
    if value > 100
      errors << warning("Large value", span).build
    end
    if value == 0
      errors << hint("Zero value", span).build
    end
  end
  
  finalize_ast TestNode
end

describe "Hecate::AST::StructuralValidator" do
  it "detects simple cycles" do
    # Create a simple cycle: A -> B -> A
    node_a = StructuralTestNode.new(make_span(0, 1))
    node_b = StructuralTestNode.new(make_span(2, 3))
    node_a.add_child(node_b)
    node_b.add_child(node_a)
    
    validator = Hecate::AST::StructuralValidator.new
    validator.validate_structure(node_a)
    
    all_errors = validator.all_errors
    all_errors.any? { |e| e.message.includes?("Circular reference") }.should be_true
  end
  
  it "detects self-referencing nodes" do
    # Create a node that references itself
    node = StructuralTestNode.new(make_span())
    node.add_child(node)
    
    validator = Hecate::AST::StructuralValidator.new
    validator.validate_structure(node)
    
    all_errors = validator.all_errors
    all_errors.any? { |e| e.message.includes?("Circular reference") }.should be_true
  end
  
  it "detects complex cycles" do
    # Create a more complex cycle: A -> B -> C -> B
    node_a = StructuralTestNode.new(make_span(0, 1))
    node_b = StructuralTestNode.new(make_span(2, 3))
    node_c = StructuralTestNode.new(make_span(4, 5))
    
    node_a.add_child(node_b)
    node_b.add_child(node_c)
    node_c.add_child(node_b)  # Create the cycle
    
    validator = Hecate::AST::StructuralValidator.new
    validator.validate_structure(node_a)
    
    errors = validator.all_errors
    errors.any? { |e| e.message.includes?("Circular reference") }.should be_true
  end
  
  it "handles valid tree structures without errors" do
    # Create a valid tree: A -> B -> C
    node_a = StructuralTestNode.new(make_span(0, 1))
    node_b = StructuralTestNode.new(make_span(2, 3))
    node_c = StructuralTestNode.new(make_span(4, 5))
    
    node_a.add_child(node_b)
    node_b.add_child(node_c)
    
    validator = Hecate::AST::StructuralValidator.new
    validator.validate_structure(node_a)
    
    validator.structural_errors.should be_empty
  end
  
  it "combines structural and custom validation errors" do
    # Create a node with custom validation error
    node = StructuralTestAST::PositiveInt.new(make_span(), -5)
    
    validator = Hecate::AST::StructuralValidator.new
    validator.validate_structure(node)
    
    all_errors = validator.all_errors
    all_errors.size.should eq(1)
    all_errors.first.message.should contain("must be positive")
  end
  
  it "provides detailed cycle diagnostics" do
    # Create a cycle with multiple nodes for better diagnostics
    node_a = StructuralTestNode.new(make_span(0, 1))
    node_b = StructuralTestNode.new(make_span(2, 3))
    node_c = StructuralTestNode.new(make_span(4, 5))
    node_d = StructuralTestNode.new(make_span(6, 7))
    
    node_a.add_child(node_b)
    node_b.add_child(node_c)
    node_c.add_child(node_d)
    node_d.add_child(node_b)  # Create cycle: D -> B
    
    validator = Hecate::AST::StructuralValidator.new
    validator.validate_structure(node_a)
    
    errors = validator.all_errors
    cycle_error = errors.find { |e| e.message.includes?("Circular reference") }
    cycle_error.should_not be_nil
    
    if error = cycle_error
      # Should have help text
      error.help.should_not be_nil
      error.help.not_nil!.should contain("tree structure")
      
      # Should have multiple labels showing the cycle path
      error.labels.size.should be > 1
    end
  end
end

describe "Hecate::AST::FullValidator" do
  it "provides a simple interface for complete validation" do
    # Create a valid tree
    node_a = StructuralTestNode.new(make_span(0, 1))
    node_b = StructuralTestNode.new(make_span(2, 3))
    node_c = StructuralTestNode.new(make_span(4, 5))
    
    node_a.add_child(node_b)
    node_b.add_child(node_c)
    
    validator = Hecate::AST::FullValidator.new
    errors = validator.validate(node_a)
    
    errors.should be_empty
    validator.valid?.should be_true
  end
  
  it "groups errors by severity" do
    # Create nodes with different severity errors
    node1 = SeverityTestAST::TestNode.new(make_span(0, 1), -5)    # Error
    node2 = SeverityTestAST::TestNode.new(make_span(2, 3), 150)   # Warning
    node3 = SeverityTestAST::TestNode.new(make_span(4, 5), 0)     # Hint
    
    root = StructuralTestNode.new(make_span())
    root.add_child(node1)
    root.add_child(node2)
    root.add_child(node3)
    
    validator = Hecate::AST::FullValidator.new
    validator.validate(root)
    
    errors_by_severity = validator.errors_by_severity
    
    errors_by_severity[Hecate::Core::Diagnostic::Severity::Error]?.try(&.size).should eq(1)
    errors_by_severity[Hecate::Core::Diagnostic::Severity::Warning]?.try(&.size).should eq(1)
    errors_by_severity[Hecate::Core::Diagnostic::Severity::Hint]?.try(&.size).should eq(1)
  end
end