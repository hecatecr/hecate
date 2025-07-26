require "./macros/node_generator"
require "./macros/struct_node_generator"
require "./macros/optimized_node_generator"
require "./macros/pooled_node_generator"
require "./macros/visitor_generator"
require "./macros/type_predicates"

# Define macros that will be available when Hecate::AST is included
module Hecate::AST
  macro included
    
    # Define an abstract base type
    macro abstract_node(type_name)
      abstract class \{{type_name.id}} < ::Hecate::AST::Node
      end
      
    end

    # Define a memory-optimized struct node for leaf nodes
    # Syntax examples:
    #   struct_node IntLit < Expr, value: Int32
    #   struct_node StringLit < Expr, value: String
    #   struct_node BoolLit < Expr, value: Bool
    # Note: struct_node should only be used for immutable leaf nodes
    macro struct_node(signature, *fields, &block)
      \{% 
        # Parse the signature (e.g., "Child < Parent" or just "Child")
        if signature.is_a?(Call) && signature.name == :<
          node_name = signature.receiver
          parent_type = signature.args[0]
        else
          node_name = signature
          parent_type = "::Hecate::AST::Node".id
        end
      %}
      
      # Generate the struct node with fields parsing
      \{% 
        # Parse fields into structured format (same as regular nodes)
        parsed_fields = [] of NamedTuple
        
        fields.each do |field|
          if field.is_a?(TypeDeclaration)
            field_name = field.var.id.stringify
            field_type = field.type.id.stringify
            optional = field_type.ends_with?("?") || field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil")
            
            # Validate field name
            reserved_names = ["span", "children", "accept", "clone"]
            if reserved_names.includes?(field_name)
              raise "Field name '#{field_name}' is reserved and cannot be used"
            end
            
            parsed_fields << {
              name: field.var,
              type: field.type,
              optional: optional
            }
          else
            raise "Invalid field definition: #{field}. Expected format: name : Type"
          end
        end
      %}
      
      # Generate the struct node implementation
      ::Hecate::AST::Macros.generate_struct_node(\{{node_name}}, \{{parent_type}}, \{{parsed_fields}})
      
      # Add validation method if block provided (to wrapper class)
      \{% if block && block.class_name != "Nop" %}
        class \{{node_name}}Wrapper < \{{parent_type}}
          def validate : Array(Hecate::Core::Diagnostic)
            errors = [] of Hecate::Core::Diagnostic
            \{{ block.body }}
            errors
          end
          
          # Helper methods for validation
          private def error(message : String, span : Hecate::Core::Span = @inner.span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.error(message).primary(span, "here")
          end
          
          private def warning(message : String, span : Hecate::Core::Span = @inner.span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.warning(message).primary(span, "here")
          end
          
          private def hint(message : String, span : Hecate::Core::Span = @inner.span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.hint(message).primary(span, "here")
          end
        end
      \{% end %}
    end

    # Define a memory-optimized concrete node type
    # Same interface as regular nodes but with memory and performance optimizations
    # Syntax examples:
    #   optimized_node IntLit < Expr, value: Int32
    #   optimized_node StringLit < Expr, value: String
    #   optimized_node BinaryOp < Expr, left: Expr, operator: String, right: Expr
    macro optimized_node(signature, *fields, &block)
      \{% 
        # Parse the signature (e.g., "Child < Parent" or just "Child")
        if signature.is_a?(Call) && signature.name == :<
          node_name = signature.receiver
          parent_type = signature.args[0]
        else
          node_name = signature
          parent_type = "::Hecate::AST::Node".id
        end
      %}
      
      # Generate the optimized node with fields parsing
      \{% 
        # Parse fields into structured format (same as regular nodes)
        parsed_fields = [] of NamedTuple
        
        fields.each do |field|
          if field.is_a?(TypeDeclaration)
            field_name = field.var.id.stringify
            field_type = field.type.id.stringify
            optional = field_type.ends_with?("?") || field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil")
            
            # Validate field name
            reserved_names = ["span", "children", "accept", "clone"]
            if reserved_names.includes?(field_name)
              raise "Field name '#{field_name}' is reserved and cannot be used"
            end
            
            parsed_fields << {
              name: field.var,
              type: field.type,
              optional: optional
            }
          else
            raise "Invalid field definition: #{field}. Expected format: name : Type"
          end
        end
      %}
      
      # Generate the optimized node class
      ::Hecate::AST::Macros.generate_optimized_node_class(\{{node_name}}, \{{parent_type}}, \{{parsed_fields}})
      
      # Add validation method if block provided
      \{% if block && block.class_name != "Nop" %}
        class \{{node_name}} < \{{parent_type}}
          def validate : Array(Hecate::Core::Diagnostic)
            errors = [] of Hecate::Core::Diagnostic
            \{{ block.body }}
            errors
          end
          
          # Helper methods for validation
          private def error(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.error(message).primary(span, "here")
          end
          
          private def warning(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.warning(message).primary(span, "here")
          end
          
          private def hint(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.hint(message).primary(span, "here")
          end
        end
      \{% end %}
    end

    # Define a memory-optimized concrete node type with object pooling
    # Combines optimized layout with pooling for common literal values
    # Syntax examples:
    #   pooled_node IntLit < Expr, value: Int32
    #   pooled_node BoolLit < Expr, value: Bool
    #   pooled_node StringLit < Expr, value: String
    #   pooled_node Identifier < Expr, name: String
    macro pooled_node(signature, *fields, &block)
      \{% 
        # Parse the signature (e.g., "Child < Parent" or just "Child")
        if signature.is_a?(Call) && signature.name == :<
          node_name = signature.receiver
          parent_type = signature.args[0]
        else
          node_name = signature
          parent_type = "::Hecate::AST::Node".id
        end
      %}
      
      # Generate the pooled node with fields parsing
      \{% 
        # Parse fields into structured format (same as regular nodes)
        parsed_fields = [] of NamedTuple
        
        fields.each do |field|
          if field.is_a?(TypeDeclaration)
            field_name = field.var.id.stringify
            field_type = field.type.id.stringify
            optional = field_type.ends_with?("?") || field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil")
            
            # Validate field name
            reserved_names = ["span", "children", "accept", "clone"]
            if reserved_names.includes?(field_name)
              raise "Field name '#{field_name}' is reserved and cannot be used"
            end
            
            parsed_fields << {
              name: field.var,
              type: field.type,
              optional: optional
            }
          else
            raise "Invalid field definition: #{field}. Expected format: name : Type"
          end
        end
      %}
      
      # Generate the pooled node class
      ::Hecate::AST::Macros.generate_pooled_node_class(\{{node_name}}, \{{parent_type}}, \{{parsed_fields}})
      
      # Add validation method if block provided
      \{% if block && block.class_name != "Nop" %}
        class \{{node_name}} < \{{parent_type}}
          def validate : Array(Hecate::Core::Diagnostic)
            errors = [] of Hecate::Core::Diagnostic
            \{{ block.body }}
            errors
          end
          
          # Helper methods for validation
          private def error(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.error(message).primary(span, "here")
          end
          
          private def warning(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.warning(message).primary(span, "here")
          end
          
          private def hint(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.hint(message).primary(span, "here")
          end
        end
      \{% end %}
    end

    # Define a concrete node type
    # Syntax examples:
    #   node IntLit < Expr, value: Int32
    #   node Add < Expr, left: Expr, right: Expr
    #   node VarDecl < Stmt, name: String, value: Expr?
    #   node IntLit < Expr, value: Int32 do
    #     validate do
    #       errors << error("Value must be positive", span) if value < 0
    #     end
    #   end
    macro node(signature, *fields, &block)
      \{% 
        # Parse the signature (e.g., "Child < Parent" or just "Child")
        if signature.is_a?(Call) && signature.name == :<
          node_name = signature.receiver
          parent_type = signature.args[0]
        else
          node_name = signature
          parent_type = "::Hecate::AST::Node".id
        end
      %}
      
      # Generate the node class with fields parsing restored
      \{% 
        # Parse fields into structured format
        parsed_fields = [] of NamedTuple
        
        fields.each do |field|
          if field.is_a?(TypeDeclaration)
            field_name = field.var.id.stringify
            field_type = field.type.id.stringify
            # Detect optional fields: either ends with ? or is a union with Nil
            optional = field_type.ends_with?("?") || field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil")
            
            # Validate field name
            reserved_names = ["span", "children", "accept", "clone"]
            if reserved_names.includes?(field_name)
              raise "Field name '#{field_name}' is reserved and cannot be used"
            end
            
            parsed_fields << {
              name: field.var,
              type: field.type,
              optional: optional
            }
          else
            raise "Invalid field definition: #{field}. Expected format: name : Type"
          end
        end
      %}
      
      
      # Generate the node class directly here to preserve block context
      ::Hecate::AST::Macros.generate_node_class(\{{node_name}}, \{{parent_type}}, \{{parsed_fields}})
      
      # Add validation method if block provided
      \{% if block && block.class_name != "Nop" %}
        class \{{node_name}} < \{{parent_type}}
          def validate : Array(Hecate::Core::Diagnostic)
            errors = [] of Hecate::Core::Diagnostic
            \{{ block.body }}
            errors
          end
          
          # Helper methods for validation
          private def error(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.error(message).primary(span, "here")
          end
          
          private def warning(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.warning(message).primary(span, "here")
          end
          
          private def hint(message : String, span : Hecate::Core::Span = @span) : Hecate::Core::DiagnosticBuilder
            Hecate::Core.hint(message).primary(span, "here")
          end
        end
      \{% end %}
    end
    
    # Generate a builder method for a specific node type
    # Usage: generate_builder(IntLit, value : Int32)
    # Usage: generate_builder(Add, left : Expr, right : Expr)
    macro generate_builder(node_type, *fields)
      \{% unless @type.has_constant?("Builder") %}
        module Builder
          extend self
          
          # Default span for builder-constructed nodes
          DEFAULT_SPAN = ::Hecate::Core::Span.new(0_u32, 0, 0)
          
          # Block-based DSL construction
          def build(&block)
            with self yield
          end
          
          # Calculate a span that encompasses all child nodes
          def span_for(*nodes : ::Hecate::AST::Node) : ::Hecate::Core::Span
            return DEFAULT_SPAN if nodes.empty?
            
            source_id = nodes.first.span.source_id
            start_byte = nodes.map(&.span.start_byte).min
            end_byte = nodes.map(&.span.end_byte).max
            
            ::Hecate::Core::Span.new(source_id, start_byte, end_byte)
          end
          
          # Helper for optional values with automatic type inference
          def optional(value : T) : T? forall T
            value
          end
          
          def optional(value : Nil) : Nil
            nil
          end
        end
      \{% end %}
      
      module Builder
        # Builder method for \{{node_type}} with explicit span
        def \{{node_type.id.underscore}}(
          \{% for field in fields %}
            \{{field}},
          \{% end %}
          span : ::Hecate::Core::Span = DEFAULT_SPAN
        ) : \{{node_type}}
          \{{node_type}}.new(
            span,
            \{% for field in fields %}
              \{% if field.is_a?(TypeDeclaration) %}
                \{{field.var}},
              \{% else %}
                \{{field}},
              \{% end %}
            \{% end %}
          )
        end
        
      end
    end
    
    # Add convenience methods for common AST construction patterns
    # Usage: add_builder_conveniences
    macro add_builder_conveniences
      \{% unless @type.has_constant?("Builder") %}
        module Builder
          extend self
          
          # Default span for builder-constructed nodes
          DEFAULT_SPAN = ::Hecate::Core::Span.new(0_u32, 0, 0)
          
          # Block-based DSL construction
          def build(&block)
            with self yield
          end
        end
      \{% end %}
      
      module Builder
        # Convenience method for creating lists of nodes
        def list(*nodes : ::Hecate::AST::Node)
          nodes.to_a
        end
        
        # Convenience method for optional nodes
        def some(node : ::Hecate::AST::Node) : ::Hecate::AST::Node?
          node
        end
        
        def none : ::Hecate::AST::Node?
          nil
        end
        
        # Helper for building block-like structures
        def block(*statements : ::Hecate::AST::Node)
          # This would be used with a Block node type if defined
          # block(stmt1, stmt2, stmt3)
          statements.to_a
        end
        
        # Helper for binary operations with automatic span calculation
        def binary(op : String, left : ::Hecate::AST::Node, right : ::Hecate::AST::Node, span : ::Hecate::Core::Span? = nil)
          final_span = span || span_for(left, right)
          # This assumes a BinaryOp node type exists
          # Users would define their own binary operation node and use generate_builder for it
          {op, left, right, final_span}
        end
      end
    end
    
    # Finalize AST definition and generate visitor infrastructure and type predicates
    macro finalize_ast(*node_types)
      # Generate abstract Visitor(T) class
      abstract class Visitor(T)
        \{% for node_type in node_types %}
          abstract def visit_\{{node_type.id.underscore}}(node : \{{node_type}}) : T
        \{% end %}
        
        # Generic visit method that delegates to node's accept method
        def visit(node : ::Hecate::AST::Node) : T
          node.accept(self)
        end
      end
      
      # Generate Transformer base class for AST transformations
      abstract class Transformer < Visitor(::Hecate::AST::Node)
        \{% for node_type in node_types %}
          # Default implementation: just return the node as-is
          # Users can override specific visit methods to implement transformations
          def visit_\{{node_type.id.underscore}}(node : \{{node_type}}) : ::Hecate::AST::Node
            node
          end
        \{% end %}
      end
      
      
      # Generate type predicate methods for pattern matching and type discrimination
      ::Hecate::AST::Macros.generate_type_predicates(\{{node_types.splat}})
    end
  end
end