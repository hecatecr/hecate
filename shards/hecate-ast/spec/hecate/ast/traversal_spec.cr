require "../../spec_helper"
require "../../../src/hecate/ast/traversal"

# Mock AST nodes for testing traversal
class MockNode < Hecate::AST::Node
  getter name : String
  getter child_nodes : Array(Hecate::AST::Node)

  def initialize(@name : String, child_nodes = [] of Hecate::AST::Node, span = Hecate::Core::Span.new(0_u32, 0, 0))
    @child_nodes = child_nodes.map(&.as(Hecate::AST::Node))
    super(span)
  end

  def children : Array(Hecate::AST::Node)
    @child_nodes
  end

  def accept(visitor)
    # Mock implementation for testing
  end

  def clone : self
    MockNode.new(@name, @child_nodes.map(&.clone), @span)
  end

  def to_s(io : IO) : Nil
    io << @name
  end
end

# Additional mock node types for testing type-safe find_all
class MockLiteral < MockNode
  def initialize(name : String, child_nodes = [] of Hecate::AST::Node)
    super(name, child_nodes)
  end
end

class MockIdentifier < MockNode
  def initialize(name : String, child_nodes = [] of Hecate::AST::Node)
    super(name, child_nodes)
  end
end

class MockBinaryOp < MockNode
  def initialize(name : String, child_nodes = [] of Hecate::AST::Node)
    super(name, child_nodes)
  end
end

describe Hecate::AST::TreeWalk do
  describe ".preorder" do
    it "visits single node" do
      root = MockNode.new("root")
      visited = [] of String

      Hecate::AST::TreeWalk.preorder(root) do |node|
        visited << node.as(MockNode).name
      end

      visited.should eq ["root"]
    end

    it "visits nodes in preorder sequence" do
      # Create tree structure:
      #     root
      #    /    \
      #   a      b
      #  / \      \
      # c   d      e
      c = MockNode.new("c")
      d = MockNode.new("d")
      e = MockNode.new("e")
      a = MockNode.new("a", [c, d])
      b = MockNode.new("b", [e])
      root = MockNode.new("root", [a, b])

      visited = [] of String

      Hecate::AST::TreeWalk.preorder(root) do |node|
        visited << node.as(MockNode).name
      end

      # Preorder: root, a, c, d, b, e
      visited.should eq ["root", "a", "c", "d", "b", "e"]
    end

    it "handles linear chain" do
      # Create linear chain: root -> a -> b -> c
      c = MockNode.new("c")
      b = MockNode.new("b", [c])
      a = MockNode.new("a", [b])
      root = MockNode.new("root", [a])

      visited = [] of String

      Hecate::AST::TreeWalk.preorder(root) do |node|
        visited << node.as(MockNode).name
      end

      visited.should eq ["root", "a", "b", "c"]
    end
  end

  describe ".postorder" do
    it "visits single node" do
      root = MockNode.new("root")
      visited = [] of String

      Hecate::AST::TreeWalk.postorder(root) do |node|
        visited << node.as(MockNode).name
      end

      visited.should eq ["root"]
    end

    it "visits nodes in postorder sequence" do
      # Create tree structure:
      #     root
      #    /    \
      #   a      b
      #  / \      \
      # c   d      e
      c = MockNode.new("c")
      d = MockNode.new("d")
      e = MockNode.new("e")
      a = MockNode.new("a", [c, d])
      b = MockNode.new("b", [e])
      root = MockNode.new("root", [a, b])

      visited = [] of String

      Hecate::AST::TreeWalk.postorder(root) do |node|
        visited << node.as(MockNode).name
      end

      # Postorder: c, d, a, e, b, root
      visited.should eq ["c", "d", "a", "e", "b", "root"]
    end

    it "handles linear chain" do
      # Create linear chain: root -> a -> b -> c
      c = MockNode.new("c")
      b = MockNode.new("b", [c])
      a = MockNode.new("a", [b])
      root = MockNode.new("root", [a])

      visited = [] of String

      Hecate::AST::TreeWalk.postorder(root) do |node|
        visited << node.as(MockNode).name
      end

      visited.should eq ["c", "b", "a", "root"]
    end
  end

  describe ".level_order" do
    it "visits single node" do
      root = MockNode.new("root")
      visited = [] of String

      Hecate::AST::TreeWalk.level_order(root) do |node|
        visited << node.as(MockNode).name
      end

      visited.should eq ["root"]
    end

    it "visits nodes in level-order sequence" do
      # Create tree structure:
      #     root      (level 0)
      #    /    \
      #   a      b    (level 1)
      #  / \      \
      # c   d      e  (level 2)
      c = MockNode.new("c")
      d = MockNode.new("d")
      e = MockNode.new("e")
      a = MockNode.new("a", [c, d])
      b = MockNode.new("b", [e])
      root = MockNode.new("root", [a, b])

      visited = [] of String

      Hecate::AST::TreeWalk.level_order(root) do |node|
        visited << node.as(MockNode).name
      end

      # Level-order: root, a, b, c, d, e
      visited.should eq ["root", "a", "b", "c", "d", "e"]
    end

    it "handles linear chain" do
      # Create linear chain: root -> a -> b -> c
      c = MockNode.new("c")
      b = MockNode.new("b", [c])
      a = MockNode.new("a", [b])
      root = MockNode.new("root", [a])

      visited = [] of String

      Hecate::AST::TreeWalk.level_order(root) do |node|
        visited << node.as(MockNode).name
      end

      visited.should eq ["root", "a", "b", "c"]
    end

    it "handles wide tree" do
      # Create wide tree: root with many children
      children = (1..5).map { |i| MockNode.new("child#{i}") }
      root = MockNode.new("root", children.map(&.as(Hecate::AST::Node)))

      visited = [] of String

      Hecate::AST::TreeWalk.level_order(root) do |node|
        visited << node.as(MockNode).name
      end

      visited.should eq ["root", "child1", "child2", "child3", "child4", "child5"]
    end
  end

  describe ".find_all" do
    it "finds all nodes of specific type" do
      # Create mixed tree with different node types
      lit1 = MockLiteral.new("42")
      lit2 = MockLiteral.new("true")
      id1 = MockIdentifier.new("x")
      id2 = MockIdentifier.new("y")

      # Structure: root(binop) -> [id1, lit1], [id2, lit2]
      binop1 = MockBinaryOp.new("+", [id1, lit1])
      binop2 = MockBinaryOp.new("*", [id2, lit2])
      root = MockBinaryOp.new("=", [binop1, binop2])

      # Find all literals
      literals = Hecate::AST::TreeWalk.find_all(root, MockLiteral)
      literals.map(&.name).should eq ["42", "true"]

      # Find all identifiers
      identifiers = Hecate::AST::TreeWalk.find_all(root, MockIdentifier)
      identifiers.map(&.name).should eq ["x", "y"]

      # Find all binary operations
      binops = Hecate::AST::TreeWalk.find_all(root, MockBinaryOp)
      binops.map(&.name).should eq ["=", "+", "*"]
    end

    it "returns empty array when no matches found" do
      root = MockNode.new("root")
      literals = Hecate::AST::TreeWalk.find_all(root, MockLiteral)
      literals.should be_empty
    end

    it "returns typed array with correct Crystal type" do
      lit1 = MockLiteral.new("42")
      lit2 = MockLiteral.new("true")
      root = MockNode.new("root", [lit1, lit2])

      # The compiler should infer Array(MockLiteral)
      literals = Hecate::AST::TreeWalk.find_all(root, MockLiteral)
      literals.should be_a(Array(MockLiteral))
      literals.size.should eq 2
    end

    it "finds nodes in preorder sequence" do
      # Create tree where order matters
      lit1 = MockLiteral.new("first")
      lit2 = MockLiteral.new("second")
      lit3 = MockLiteral.new("third")

      # Structure where preorder should be: first, second, third
      child = MockNode.new("child", [lit2, lit3])
      root = MockNode.new("root", [lit1, child])

      literals = Hecate::AST::TreeWalk.find_all(root, MockLiteral)
      literals.map(&.name).should eq ["first", "second", "third"]
    end
  end

  describe ".with_depth" do
    it "provides correct depth for single node" do
      root = MockNode.new("root")
      visited = [] of {String, Int32}

      Hecate::AST::TreeWalk.with_depth(root) do |node, depth|
        visited << {node.as(MockNode).name, depth}
      end

      visited.should eq [{"root", 0}]
    end

    it "tracks depth correctly in tree structure" do
      # Create tree structure:
      #     root      (depth 0)
      #    /    \
      #   a      b    (depth 1)
      #  / \      \
      # c   d      e  (depth 2)
      c = MockNode.new("c")
      d = MockNode.new("d")
      e = MockNode.new("e")
      a = MockNode.new("a", [c, d])
      b = MockNode.new("b", [e])
      root = MockNode.new("root", [a, b])

      visited = [] of {String, Int32}

      Hecate::AST::TreeWalk.with_depth(root) do |node, depth|
        visited << {node.as(MockNode).name, depth}
      end

      # Should visit in preorder with correct depths
      visited.should eq [
        {"root", 0},
        {"a", 1}, {"c", 2}, {"d", 2},
        {"b", 1}, {"e", 2},
      ]
    end

    it "handles linear chain with increasing depth" do
      # Create linear chain: root -> a -> b -> c
      c = MockNode.new("c")
      b = MockNode.new("b", [c])
      a = MockNode.new("a", [b])
      root = MockNode.new("root", [a])

      visited = [] of {String, Int32}

      Hecate::AST::TreeWalk.with_depth(root) do |node, depth|
        visited << {node.as(MockNode).name, depth}
      end

      visited.should eq [
        {"root", 0},
        {"a", 1},
        {"b", 2},
        {"c", 3},
      ]
    end

    it "handles unbalanced tree correctly" do
      # Create unbalanced tree
      deep_node = MockNode.new("deep")
      medium_node = MockNode.new("medium", [deep_node])
      shallow_node = MockNode.new("shallow")
      root = MockNode.new("root", [medium_node, shallow_node])

      visited = [] of {String, Int32}

      Hecate::AST::TreeWalk.with_depth(root) do |node, depth|
        visited << {node.as(MockNode).name, depth}
      end

      visited.should eq [
        {"root", 0},
        {"medium", 1}, {"deep", 2},
        {"shallow", 1},
      ]
    end

    it "can be used to find nodes at specific depth" do
      # Create multi-level tree
      leaf1 = MockNode.new("leaf1")
      leaf2 = MockNode.new("leaf2")
      leaf3 = MockNode.new("leaf3")
      branch1 = MockNode.new("branch1", [leaf1, leaf2])
      branch2 = MockNode.new("branch2", [leaf3])
      root = MockNode.new("root", [branch1, branch2])

      # Find all nodes at depth 2 (leaves)
      depth_2_nodes = [] of String

      Hecate::AST::TreeWalk.with_depth(root) do |node, depth|
        if depth == 2
          depth_2_nodes << node.as(MockNode).name
        end
      end

      depth_2_nodes.should eq ["leaf1", "leaf2", "leaf3"]
    end
  end

  # Edge case testing
  describe "edge cases" do
    it "handles nodes with empty children arrays" do
      root = MockNode.new("root", [] of Hecate::AST::Node)

      # All traversal methods should work with empty children
      preorder_count = 0
      Hecate::AST::TreeWalk.preorder(root) { |_| preorder_count += 1 }
      preorder_count.should eq 1

      postorder_count = 0
      Hecate::AST::TreeWalk.postorder(root) { |_| postorder_count += 1 }
      postorder_count.should eq 1

      level_order_count = 0
      Hecate::AST::TreeWalk.level_order(root) { |_| level_order_count += 1 }
      level_order_count.should eq 1

      depth_visits = [] of Int32
      Hecate::AST::TreeWalk.with_depth(root) { |_, depth| depth_visits << depth }
      depth_visits.should eq [0]
    end

    it "handles large trees efficiently" do
      # Create a deeper tree structure for performance testing
      # Build a tree with 1000 nodes in a somewhat balanced structure
      nodes = (1..1000).map { |i| MockNode.new("node#{i}") }

      # Create a tree where each node has 2-3 children (except leaves)
      root = nodes[0]
      current_level = [root]
      remaining_nodes = nodes[1..]

      while !remaining_nodes.empty? && !current_level.empty?
        next_level = [] of MockNode

        current_level.each do |parent|
          # Give each parent 2-3 children if nodes are available
          children_count = [2, 3, remaining_nodes.size].min
          children = remaining_nodes.shift(children_count).map(&.as(Hecate::AST::Node))
          parent.child_nodes.concat(children)
          next_level.concat(children.map(&.as(MockNode)))
        end

        current_level = next_level
      end

      # Test that all traversal methods can handle the large tree
      node_count = 0
      Hecate::AST::TreeWalk.preorder(root) { |_| node_count += 1 }
      node_count.should eq 1000

      # Find all nodes should also work
      all_nodes = Hecate::AST::TreeWalk.find_all(root, MockNode)
      all_nodes.size.should eq 1000
    end

    it "handles deeply nested linear chains" do
      # Create a chain of 100 nodes deep
      current = MockNode.new("leaf")
      (1..99).reverse_each do |i|
        parent = MockNode.new("node#{i}", [current])
        current = parent
      end
      root = current

      # Test depth tracking works correctly for deep chains
      max_depth = 0
      Hecate::AST::TreeWalk.with_depth(root) do |_, depth|
        max_depth = depth if depth > max_depth
      end
      max_depth.should eq 99

      # Test that preorder visits all nodes
      visited_count = 0
      Hecate::AST::TreeWalk.preorder(root) { |_| visited_count += 1 }
      visited_count.should eq 100
    end

    it "maintains consistent traversal order across multiple calls" do
      # Create a complex tree
      nodes = (1..20).map { |i| MockNode.new("node#{i}") }
      root = nodes[0]

      # Build a specific tree structure
      root.child_nodes.concat([nodes[1], nodes[2]].map(&.as(Hecate::AST::Node)))
      nodes[1].child_nodes.concat([nodes[3], nodes[4], nodes[5]].map(&.as(Hecate::AST::Node)))
      nodes[2].child_nodes.concat([nodes[6], nodes[7]].map(&.as(Hecate::AST::Node)))
      nodes[3].child_nodes.concat([nodes[8], nodes[9]].map(&.as(Hecate::AST::Node)))

      # Run traversal multiple times and verify consistent order
      first_run = [] of String
      second_run = [] of String
      third_run = [] of String

      Hecate::AST::TreeWalk.preorder(root) { |n| first_run << n.as(MockNode).name }
      Hecate::AST::TreeWalk.preorder(root) { |n| second_run << n.as(MockNode).name }
      Hecate::AST::TreeWalk.preorder(root) { |n| third_run << n.as(MockNode).name }

      first_run.should eq second_run
      second_run.should eq third_run

      # Verify the expected preorder sequence
      expected = ["node1", "node2", "node4", "node9", "node10", "node5", "node6", "node3", "node7", "node8"]
      first_run.should eq expected
    end
  end
end
