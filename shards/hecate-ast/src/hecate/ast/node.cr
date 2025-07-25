require "hecate-core"

module Hecate::AST
  # Base class for all AST nodes. Provides common functionality including:
  # - Source location tracking via spans
  # - Visitor pattern support
  # - Deep equality comparison
  # - Deep cloning
  # - Tree traversal helpers
  abstract class Node
    # The source location of this node
    getter span : Hecate::Core::Span

    def initialize(@span : Hecate::Core::Span)
    end

    # Accept a visitor for the visitor pattern
    abstract def accept(visitor)

    # Return all child nodes for tree traversal
    abstract def children : Array(Node)

    # Deep structural equality check
    def ==(other : self) : Bool
      # First check if it's the same object
      return true if same?(other)
      
      # Check if spans are equal
      return false unless span == other.span
      
      # Check if both have the same children
      self_children = children
      other_children = other.children
      
      return false unless self_children.size == other_children.size
      
      # Recursively compare all children
      self_children.zip(other_children) do |child1, child2|
        # Handle nil children
        if child1.nil? != child2.nil?
          return false
        end
        
        # If both are non-nil, compare them
        if child1 && child2
          return false unless child1 == child2
        end
      end
      
      true
    end

    # Type-safe equality for different node types
    def ==(other) : Bool
      false
    end

    # Deep clone of the node and all its children
    def clone : self
      # This will be overridden by the generated node classes
      # to provide proper cloning with all fields
      raise "Node#clone must be implemented by subclasses"
    end

    # Human-readable string representation for debugging
    def to_s(io : IO) : Nil
      # Format: NodeType[start_byte-end_byte]
      io << self.class.name.split("::").last
      io << '['
      io << span.start_byte << '-' << span.end_byte
      io << ']'
    end

    # Check if this node is a leaf (has no children)
    def leaf? : Bool
      children.empty?
    end

    # Calculate the depth of the subtree rooted at this node
    def depth : Int32
      return 0 if leaf?
      
      max_child_depth = children.compact.map(&.depth).max? || 0
      max_child_depth + 1
    end

    # Count total nodes in the subtree rooted at this node
    def node_count : Int32
      1 + children.compact.sum(0, &.node_count)
    end

    # Find all nodes of a specific type in the subtree
    def find_all(type : T.class) : Array(T) forall T
      nodes = [] of T
      
      # Check if this node is of the requested type
      if self.is_a?(T)
        nodes << self
      end
      
      # Recursively search children
      children.compact.each do |child|
        nodes.concat(child.find_all(type))
      end
      
      nodes
    end

    # Find the first node of a specific type in the subtree
    def find_first(type : T.class) : T? forall T
      # Check if this node is of the requested type
      return self if self.is_a?(T)
      
      # Recursively search children
      children.compact.each do |child|
        if result = child.find_first(type)
          return result
        end
      end
      
      nil
    end

    # Check if this node contains a node of the given type
    def contains?(type : T.class) : Bool forall T
      !find_first(type).nil?
    end

    # Get the parent node (set by the DSL when building the tree)
    # This is optional and may be nil for root nodes
    property parent : Node?

    # Traverse the tree from this node to the root
    def ancestors : Array(Node)
      nodes = [] of Node
      current = parent
      
      while current
        nodes << current
        current = current.parent
      end
      
      nodes
    end

    # Check if this node is an ancestor of the given node
    def ancestor_of?(node : Node) : Bool
      node.ancestors.includes?(self)
    end

    # Check if this node is a descendant of the given node  
    def descendant_of?(node : Node) : Bool
      ancestors.includes?(node)
    end

    # Get all sibling nodes (nodes with the same parent)
    def siblings : Array(Node)
      p = parent
      return [] of Node unless p
      
      p.children.compact.reject { |child| child.same?(self) }
    end
  end
end