require "../../spec_helper"

# Test implementations of Node for testing
class TestNode < Hecate::AST::Node
  getter value : String
  getter child : Hecate::AST::Node?

  def initialize(@value : String, @child : Hecate::AST::Node?, span : Hecate::Core::Span)
    super(span)
  end

  def accept(visitor)
    # Stub implementation for testing
  end

  def children : Array(Hecate::AST::Node)
    child ? [child.as(Hecate::AST::Node)] : [] of Hecate::AST::Node
  end

  def clone : self
    TestNode.new(@value, @child.try(&.clone), @span)
  end

  def ==(other : self) : Bool
    super && @value == other.value
  end
end

class TestLeafNode < Hecate::AST::Node
  getter value : Int32

  def initialize(@value : Int32, span : Hecate::Core::Span)
    super(span)
  end

  def accept(visitor)
    # Stub implementation for testing
  end

  def children : Array(Hecate::AST::Node)
    [] of Hecate::AST::Node
  end

  def clone : self
    TestLeafNode.new(@value, @span)
  end

  def ==(other : self) : Bool
    super && @value == other.value
  end
end

class TestBinaryNode < Hecate::AST::Node
  getter left : Hecate::AST::Node
  getter right : Hecate::AST::Node

  def initialize(@left : Hecate::AST::Node, @right : Hecate::AST::Node, span : Hecate::Core::Span)
    super(span)
  end

  def accept(visitor)
    # Stub implementation for testing
  end

  def children : Array(Hecate::AST::Node)
    [@left, @right]
  end

  def clone : self
    TestBinaryNode.new(@left.clone, @right.clone, @span)
  end
end

# Helper to create spans
def make_span(start_byte : Int32, end_byte : Int32, source_id : UInt32 = 0_u32)
  Hecate::Core::Span.new(source_id, start_byte, end_byte)
end

describe Hecate::AST::Node do
  describe "#initialize" do
    it "stores the span" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)
      node.span.should eq(span)
    end
  end

  describe "#==" do
    it "returns true for the same object" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)
      node.should eq(node)
    end

    it "returns true for equal nodes with same span" do
      span = make_span(0, 5)
      node1 = TestLeafNode.new(42, span)
      node2 = TestLeafNode.new(42, span)
      node1.should eq(node2)
    end

    it "returns false for nodes with different spans" do
      span1 = make_span(0, 5)
      span2 = make_span(0, 6)
      node1 = TestLeafNode.new(42, span1)
      node2 = TestLeafNode.new(42, span2)
      node1.should_not eq(node2)
    end

    it "returns false for different node types" do
      span = make_span(0, 5)
      node1 = TestLeafNode.new(42, span)
      node2 = TestNode.new("test", nil, span)
      node1.should_not eq(node2)
    end

    it "recursively compares children" do
      span = make_span(0, 5)
      child1 = TestLeafNode.new(42, span)
      child2 = TestLeafNode.new(42, span)

      parent1 = TestNode.new("parent", child1, span)
      parent2 = TestNode.new("parent", child2, span)

      parent1.should eq(parent2)
    end

    it "returns false when children differ" do
      span = make_span(0, 5)
      child1 = TestLeafNode.new(42, span)
      child2 = TestLeafNode.new(43, span)

      parent1 = TestNode.new("parent", child1, span)
      parent2 = TestNode.new("parent", child2, span)

      parent1.should_not eq(parent2)
    end

    it "handles nil children correctly" do
      span = make_span(0, 5)
      child = TestLeafNode.new(42, span)

      parent1 = TestNode.new("parent", child, span)
      parent2 = TestNode.new("parent", nil, span)

      parent1.should_not eq(parent2)
    end
  end

  describe "#clone" do
    it "creates a deep copy of a leaf node" do
      span = make_span(0, 5)
      original = TestLeafNode.new(42, span)
      cloned = original.clone

      cloned.should eq(original)
      cloned.should_not be(original)
      cloned.span.should eq(original.span)
    end

    it "creates a deep copy of a node with children" do
      span = make_span(0, 5)
      child = TestLeafNode.new(42, span)
      original = TestNode.new("parent", child, span)
      cloned = original.clone

      cloned.should eq(original)
      cloned.should_not be(original)
      cloned.child.should_not be(original.child)
    end

    it "recursively clones entire tree" do
      span = make_span(0, 5)
      left = TestLeafNode.new(1, span)
      right = TestLeafNode.new(2, span)
      binary = TestBinaryNode.new(left, right, span)

      cloned = binary.clone

      cloned.should eq(binary)
      cloned.should_not be(binary)
      cloned.left.should_not be(binary.left)
      cloned.right.should_not be(binary.right)
    end
  end

  describe "#to_s" do
    it "formats leaf nodes correctly" do
      span = make_span(5, 10)
      node = TestLeafNode.new(42, span)
      node.to_s.should eq("TestLeafNode[5-10]")
    end

    it "formats nodes with different spans" do
      span = make_span(100, 200)
      node = TestLeafNode.new(42, span)
      node.to_s.should eq("TestLeafNode[100-200]")
    end
  end

  describe "#leaf?" do
    it "returns true for nodes with no children" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)
      node.leaf?.should be_true
    end

    it "returns false for nodes with children" do
      span = make_span(0, 5)
      child = TestLeafNode.new(42, span)
      node = TestNode.new("parent", child, span)
      node.leaf?.should be_false
    end
  end

  describe "#depth" do
    it "returns 0 for leaf nodes" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)
      node.depth.should eq(0)
    end

    it "calculates depth correctly for simple trees" do
      span = make_span(0, 5)
      child = TestLeafNode.new(42, span)
      parent = TestNode.new("parent", child, span)
      parent.depth.should eq(1)
    end

    it "calculates depth correctly for deeper trees" do
      span = make_span(0, 5)
      leaf1 = TestLeafNode.new(1, span)
      leaf2 = TestLeafNode.new(2, span)
      binary = TestBinaryNode.new(leaf1, leaf2, span)
      root = TestNode.new("root", binary, span)

      root.depth.should eq(2)
    end
  end

  describe "#node_count" do
    it "returns 1 for leaf nodes" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)
      node.node_count.should eq(1)
    end

    it "counts all nodes in the tree" do
      span = make_span(0, 5)
      leaf1 = TestLeafNode.new(1, span)
      leaf2 = TestLeafNode.new(2, span)
      binary = TestBinaryNode.new(leaf1, leaf2, span)

      binary.node_count.should eq(3) # binary + 2 leaves
    end
  end

  describe "#find_all" do
    it "finds all nodes of a specific type" do
      span = make_span(0, 5)
      leaf1 = TestLeafNode.new(1, span)
      leaf2 = TestLeafNode.new(2, span)
      binary = TestBinaryNode.new(leaf1, leaf2, span)

      leaves = binary.find_all(TestLeafNode)
      leaves.size.should eq(2)
      leaves.should contain(leaf1)
      leaves.should contain(leaf2)
    end

    it "includes self if it matches the type" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)

      result = node.find_all(TestLeafNode)
      result.size.should eq(1)
      result.first.should be(node)
    end

    it "returns empty array when no matches found" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)

      result = node.find_all(TestBinaryNode)
      result.should be_empty
    end
  end

  describe "#find_first" do
    it "finds the first node of a specific type" do
      span = make_span(0, 5)
      leaf1 = TestLeafNode.new(1, span)
      leaf2 = TestLeafNode.new(2, span)
      binary = TestBinaryNode.new(leaf1, leaf2, span)

      result = binary.find_first(TestLeafNode)
      result.should eq(leaf1)
    end

    it "returns self if it matches" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)

      result = node.find_first(TestLeafNode)
      result.should be(node)
    end

    it "returns nil when no match found" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)

      result = node.find_first(TestBinaryNode)
      result.should be_nil
    end
  end

  describe "#contains?" do
    it "returns true when type is found" do
      span = make_span(0, 5)
      leaf = TestLeafNode.new(42, span)
      parent = TestNode.new("parent", leaf, span)

      parent.contains?(TestLeafNode).should be_true
    end

    it "returns false when type is not found" do
      span = make_span(0, 5)
      node = TestLeafNode.new(42, span)

      node.contains?(TestBinaryNode).should be_false
    end
  end

  describe "parent/ancestor/sibling relationships" do
    it "tracks parent relationships" do
      span = make_span(0, 5)
      child = TestLeafNode.new(42, span)
      parent = TestNode.new("parent", child, span)

      child.parent = parent
      child.parent.should be(parent)
    end

    it "finds ancestors correctly" do
      span = make_span(0, 5)
      leaf = TestLeafNode.new(42, span)
      middle = TestNode.new("middle", leaf, span)
      root = TestNode.new("root", middle, span)

      leaf.parent = middle
      middle.parent = root

      ancestors = leaf.ancestors
      ancestors.size.should eq(2)
      ancestors[0].should be(middle)
      ancestors[1].should be(root)
    end

    it "checks ancestor relationships" do
      span = make_span(0, 5)
      leaf = TestLeafNode.new(42, span)
      middle = TestNode.new("middle", leaf, span)
      root = TestNode.new("root", middle, span)

      leaf.parent = middle
      middle.parent = root

      root.ancestor_of?(leaf).should be_true
      leaf.descendant_of?(root).should be_true
      leaf.ancestor_of?(root).should be_false
    end

    it "finds siblings correctly" do
      span = make_span(0, 5)
      left = TestLeafNode.new(1, span)
      right = TestLeafNode.new(2, span)
      parent = TestBinaryNode.new(left, right, span)

      left.parent = parent
      right.parent = parent

      left_siblings = left.siblings
      left_siblings.size.should eq(1)
      left_siblings.first.should be(right)

      right_siblings = right.siblings
      right_siblings.size.should eq(1)
      right_siblings.first.should be(left)
    end
  end
end
