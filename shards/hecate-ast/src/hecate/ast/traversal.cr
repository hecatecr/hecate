require "./node"

module Hecate::AST
  # Tree traversal utilities for AST nodes.
  # Provides various algorithms for walking AST trees including:
  # - Pre-order traversal (depth-first, node before children)
  # - Post-order traversal (depth-first, children before node)
  # - Level-order traversal (breadth-first)
  # - Type-safe search utilities
  # - Depth-aware traversal
  module TreeWalk
    # Perform pre-order traversal (node first, then children)
    # Visits the current node first, then recursively visits all children
    # in left-to-right order.
    #
    # ```
    # TreeWalk.preorder(root) do |node|
    #   puts "Visiting: #{node}"
    # end
    # ```
    def self.preorder(node : Node, &block : Node ->) : Nil
      block.call(node)
      node.children.each { |child| preorder(child, &block) }
    end

    # Perform post-order traversal (children first, then node)
    # Recursively visits all children first (left-to-right), then visits
    # the current node.
    #
    # ```
    # TreeWalk.postorder(root) do |node|
    #   puts "Visiting: #{node}"
    # end
    # ```
    def self.postorder(node : Node, &block : Node ->) : Nil
      node.children.each { |child| postorder(child, &block) }
      block.call(node)
    end

    # Perform level-order traversal (breadth-first)
    # Visits nodes level by level, from left to right within each level.
    # Uses a queue to maintain proper ordering.
    #
    # ```
    # TreeWalk.level_order(root) do |node|
    #   puts "Visiting: #{node}"
    # end
    # ```
    def self.level_order(node : Node, &block : Node ->) : Nil
      queue = Deque(Node).new([node])
      
      while current_node = queue.shift?
        block.call(current_node)
        queue.concat(current_node.children)
      end
    end

    # Find all nodes of a specific type in the subtree using preorder traversal
    # Returns an array of all matching nodes in preorder sequence.
    # Uses Crystal's forall constraint for type safety.
    #
    # ```
    # literals = TreeWalk.find_all(root, IntLiteral)
    # # literals is Array(IntLiteral)
    # ```
    def self.find_all(node : Node, type : T.class) : Array(T) forall T
      results = [] of T
      
      preorder(node) do |n|
        results << n if n.is_a?(T)
      end
      
      results
    end

    # Perform depth-aware traversal (preorder with depth tracking)
    # Visits nodes in preorder but also provides the depth of each node.
    # Root node starts at depth 0, children are at depth 1, etc.
    #
    # ```
    # TreeWalk.with_depth(root) do |node, depth|
    #   puts "#{depth}: #{node}"
    # end
    # ```
    def self.with_depth(node : Node, depth = 0, &block : Node, Int32 ->) : Nil
      block.call(node, depth)
      node.children.each { |child| with_depth(child, depth + 1, &block) }
    end
  end
end