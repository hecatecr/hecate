module Hecate::AST
  module Macros
    # Generate a complete node class from DSL definition
    macro generate_node_class(name, parent, fields)
      class {{name}} < {{parent}}
        # Generate getters for each field
        {% for field in fields %}
          getter {{field[:name].id}} : {{field[:type].id}}
        {% end %}
        
        # Constructor with span and all fields
        def initialize(@span : Hecate::Core::Span,
                       {% for field in fields %}
                         @{{field[:name].id}} : {{field[:type].id}},
                       {% end %})
          super(@span)
        end
        
        # Visitor pattern support
        def accept(visitor)
          visitor.visit_{{name.id.underscore}}(self)
        end
        
        # Extract child nodes for traversal
        def children : Array(Node)
          result = [] of Node
          {% for field in fields %}
            {% field_type = field[:type].id.stringify %}
            
            # List of known non-node types
            {% non_node_types = ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol", "Nil"] %}
            {% is_array = field_type.starts_with?("Array(") && field_type.ends_with?(")") %}
            
            {% if field[:optional] %}
              # Handle optional types
              # For optional fields, check if it's a basic type
              {% if field_type.ends_with?("?") %}
                {% base_type = field_type[0..-2] %}
              {% elsif field_type.includes?(" | ::Nil") %}
                # Extract the base type from "Type | ::Nil"
                {% base_type = field_type.split(" | ::Nil")[0] %}
              {% elsif field_type.includes?(" | Nil") %}
                # Extract the base type from "Type | Nil"  
                {% base_type = field_type.split(" | Nil")[0] %}
              {% else %}
                # Assume the field_type represents the optional type without ?
                {% base_type = field_type %}
              {% end %}
              
              # Whitelist approach - only exclude known non-node types
              {% is_string_array = base_type == "Array(String)" %}
              {% is_basic = non_node_types.includes?(base_type) || is_string_array %}
              
              {% unless is_basic %}
                # It's probably a node type - add the nil check
                if node = @{{field[:name].id}}
                  result << node
                end
              {% end %}
              
            {% elsif is_array %}
              # Handle arrays
              {% inner_type = field_type[6..-2] %}
              {% is_array_of_basic = non_node_types.any? { |t| inner_type == t || inner_type == "#{t}?" } %}
              
              {% unless is_array_of_basic %}
                # Assume it's an array of nodes if not basic types
                result.concat(@{{field[:name].id}})
              {% end %}
              
            {% else %}
              # Handle regular fields
              {% is_basic_type = non_node_types.includes?(field_type) %}
              {% is_union_with_nil = field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil") %}
              
              {% unless is_basic_type || is_union_with_nil %}
                # Assume it's a node type if not a basic type or union with nil
                result << @{{field[:name].id}}
              {% end %}
            {% end %}
          {% end %}
          result
        end
        
        # Deep equality comparison
        def ==(other : self) : Bool
          return false unless other.is_a?({{name}})
          
          {% for field in fields %}
            return false unless @{{field[:name].id}} == other.{{field[:name].id}}
          {% end %}
          
          true
        end
        
        # Deep clone
        def clone : self
          {{name}}.new(
            @span,
            {% for field in fields %}
              {% field_type = field[:type].id.stringify %}
              
              # List of known non-node types
              {% non_node_types = ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol", "Nil"] %}
              {% is_array = field_type.starts_with?("Array(") && field_type.ends_with?(")") %}
              
              {% if field[:optional] %}
                # Handle optional types
                # For optional fields, check if it's a basic type
                {% if field_type.ends_with?("?") %}
                  {% base_type = field_type[0..-2] %}
                {% else %}
                  # Assume the field_type represents the optional type without ?
                  {% base_type = field_type %}
                {% end %}
                
                # Whitelist approach - only exclude known non-node types
                {% is_string_array = base_type == "Array(String)" %}
                {% is_basic = non_node_types.includes?(base_type) || is_string_array %}
                
                {% if is_basic %}
                  # Copy basic type directly
                  @{{field[:name].id}},
                {% else %}
                  # Clone node type
                  @{{field[:name].id}}.try(&.clone),
                {% end %}
                
              {% elsif is_array %}
                # Handle arrays
                {% inner_type = field_type[6..-2] %}
                {% is_array_of_basic = non_node_types.any? { |t| inner_type == t || inner_type == "#{t}?" } %}
                
                {% if is_array_of_basic %}
                  # Dup array of basic types
                  @{{field[:name].id}}.dup,
                {% else %}
                  # Clone array of nodes
                  @{{field[:name].id}}.map(&.clone),
                {% end %}
                
              {% else %}
                # Handle regular fields
                {% is_basic_type = non_node_types.includes?(field_type) %}
                {% is_union_with_nil = field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil") %}
                
                {% if is_basic_type || is_union_with_nil %}
                  # Copy basic type directly
                  @{{field[:name].id}},
                {% else %}
                  # Clone node type
                  @{{field[:name].id}}.clone,
                {% end %}
              {% end %}
            {% end %}
          )
        end
        
        # Debug string representation
        def to_s(io : IO) : Nil
          io << {{name.stringify}} << "("
          {% for field, index in fields %}
            {% if index > 0 %}
              io << ", "
            {% end %}
            io << {{field[:name].stringify}} << ": "
            @{{field[:name].id}}.to_s(io)
          {% end %}
          io << ")"
        end
        
      end
    end
  end
end