module Hecate::AST
  # An enhanced validator that combines custom validation rules with structural validation capabilities.
  #
  # In addition to collecting errors from node validation methods, this validator detects:
  # - Circular references (cycles) in the AST
  # - Orphaned nodes (future feature)
  # - Type mismatches in child nodes (future feature)
  #
  # ## Cycle Detection
  # The validator tracks visited nodes and detects when a node is encountered again during traversal,
  # indicating a circular reference. It provides detailed diagnostics showing the cycle path.
  #
  # ## Example
  # ```
  # validator = Hecate::AST::StructuralValidator.new
  # validator.validate_structure(root_node)
  # 
  # if validator.all_errors.any?
  #   puts "Found structural issues:"
  #   validator.structural_errors.each { |e| puts e }
  # end
  # ```
  class StructuralValidator < ASTValidator
    # Track visited nodes for cycle detection
    @visited = Set(Node).new
    @visiting = Set(Node).new
    @parent_map = {} of Node => Node?
    @orphan_nodes = [] of Node
    @cycles = [] of Array(Node)
    @type_mismatches = [] of Hecate::Core::Diagnostic
    
    def initialize
      super
    end
    
    # Override visit to track parent-child relationships and detect issues
    def visit(node : Node) : Nil
      # Check for cycles
      if @visiting.includes?(node)
        # Found a cycle - build the cycle path
        cycle_path = build_cycle_path(node)
        @cycles << cycle_path
        
        # Create diagnostic for the cycle
        diag = Hecate::Core.error("Circular reference detected in AST")
          .primary(node.span, "cycle starts and ends here")
        
        # Add secondary labels for each node in the cycle
        cycle_path.each_with_index do |cycle_node, idx|
          next if cycle_node == node # Skip the primary node
          diag = diag.secondary(cycle_node.span, "part of cycle (step #{idx + 1})")
        end
        
        @errors << diag.help("AST nodes should form a tree structure without cycles").build
        return # Don't continue traversing from this node
      end
      
      # Mark as visiting
      @visiting << node
      
      # Run custom validation if available
      if node.responds_to?(:validate)
        node_errors = node.validate
        @errors.concat(node_errors)
      end
      
      # Check children and validate types
      node.children.each do |child|
        # Track parent relationship
        @parent_map[child] = node
        
        # Validate child type if we have type information
        validate_child_type(node, child)
        
        # Recursively visit
        visit(child)
      end
      
      # Mark as visited
      @visited << node
      @visiting.delete(node)
    end
    
    # Validate entire AST structure
    def validate_structure(root : Node) : Nil
      # Clear state
      @visited.clear
      @visiting.clear
      @parent_map.clear
      @orphan_nodes.clear
      @cycles.clear
      @type_mismatches.clear
      
      # Visit the tree
      visit(root)
      
      # Check for orphaned nodes (nodes that should have parents but don't)
      detect_orphans(root)
    end
    
    # Get all structural errors
    def structural_errors : Array(Hecate::Core::Diagnostic)
      errors = [] of Hecate::Core::Diagnostic
      
      # Add cycle errors (already added during traversal)
      # Add orphan errors
      @orphan_nodes.each do |orphan|
        errors << Hecate::Core.error("Orphaned node detected")
          .primary(orphan.span, "this node has no parent in the AST")
          .help("All non-root nodes should be referenced by a parent node")
          .build
      end
      
      # Add type mismatch errors
      errors.concat(@type_mismatches)
      
      errors
    end
    
    # Get all errors (custom validation + structural)
    def all_errors : Array(Hecate::Core::Diagnostic)
      @errors + structural_errors
    end
    
    private def build_cycle_path(node : Node) : Array(Node)
      path = [] of Node
      path << node
      current = node
      
      # Follow the path until we get back to the starting node
      loop do
        # Find a child of current that is in @visiting
        child_in_cycle = current.children.find { |c| @visiting.includes?(c) }
        break unless child_in_cycle
        
        path << child_in_cycle
        break if child_in_cycle == node
        current = child_in_cycle
      end
      
      path
    end
    
    private def validate_child_type(parent : Node, child : Node)
      # This is a simplified version - in a real implementation,
      # we'd use field metadata to know expected types
      # For now, we'll just check some common patterns
      
      case parent
      when responds_to?(:left) && responds_to?(:right)
        # Binary operation - children should typically be expressions
        unless child.is_a?(Node) # All nodes inherit from Node, so this is always true
          # In a real implementation, we'd check if it's an Expr subtype
          # For demonstration, we'll skip this check
        end
      end
      
      # Check for nil children that shouldn't be nil
      # This would require field metadata to know which fields are required
    end
    
    private def detect_orphans(root : Node)
      # In a real implementation, we'd need to collect all nodes
      # and check which ones aren't reachable from the root
      # For now, this is a placeholder
    end
  end
  
  # A high-level validator that provides a simple interface for complete AST validation.
  #
  # This validator combines both custom validation rules (from node `validate` methods)
  # and structural validation (cycle detection, etc.) in a single, easy-to-use interface.
  #
  # ## Example
  # ```
  # validator = Hecate::AST::FullValidator.new
  # errors = validator.validate(ast_root)
  # 
  # if validator.valid?
  #   puts "AST is valid!"
  # else
  #   # Group errors by severity
  #   errors_by_severity = validator.errors_by_severity
  #   errors_by_severity.each do |severity, errors|
  #     puts "#{severity}: #{errors.size} issues"
  #   end
  # end
  # ```
  class FullValidator
    @structural_validator : StructuralValidator
    
    def initialize
      @structural_validator = StructuralValidator.new
    end
    
    # Validate both custom rules and structure
    def validate(root : Node) : Array(Hecate::Core::Diagnostic)
      @structural_validator.validate_structure(root)
      @structural_validator.all_errors
    end
    
    # Check if validation passed
    def valid? : Bool
      @structural_validator.all_errors.empty?
    end
    
    # Get errors by severity
    def errors_by_severity : Hash(Hecate::Core::Diagnostic::Severity, Array(Hecate::Core::Diagnostic))
      @structural_validator.all_errors.group_by(&.severity)
    end
    
    # Clear validation state
    def clear
      @structural_validator.clear
    end
  end
end