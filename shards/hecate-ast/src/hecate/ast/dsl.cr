require "./macros/node_generator"
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

    # Define a concrete node type
    # Syntax examples:
    #   node IntLit < Expr, value: Int32
    #   node Add < Expr, left: Expr, right: Expr
    #   node VarDecl < Stmt, name: String, value: Expr?
    macro node(signature, *fields)
      \{% 
        # Parse the signature (e.g., "Child < Parent" or just "Child")
        if signature.is_a?(Call) && signature.name == :<
          node_name = signature.receiver
          parent_type = signature.args[0]
        else
          node_name = signature
          parent_type = "::Hecate::AST::Node".id
        end
        
        # Parse fields into structured format
        parsed_fields = [] of NamedTuple
        
        fields.each do |field|
          if field.is_a?(TypeDeclaration)
            field_name = field.var.id.stringify
            field_type = field.type.id.stringify
            optional = field_type.ends_with?("?")
            
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
      
      # Generate the node class
      ::Hecate::AST::Macros.generate_node_class(\{{node_name}}, \{{parent_type}}, \{{parsed_fields}})
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