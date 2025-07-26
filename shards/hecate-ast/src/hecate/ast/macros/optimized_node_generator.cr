module Hecate::AST
  module Macros
    # Generate memory-optimized node classes
    # These are still classes but with optimizations for memory usage and performance
    macro generate_optimized_node_class(name, parent, fields)
      class {{name}} < {{parent}}
        # Use explicit instance variable declarations for better memory layout
        {% for field in fields %}
          # Use getter with instance variable for memory efficiency
          @{{field[:name].id}} : {{field[:type].id}}
          
          # Manual getter for better performance (avoids method call overhead)
          def {{field[:name].id}} : {{field[:type].id}}
            @{{field[:name].id}}
          end
        {% end %}
        
        # Instance variable for span (inherited from Node but explicit for optimization)
        
        # Optimized constructor - single initialization call
        def initialize(@span : Hecate::Core::Span,
                       {% for field in fields %}
                         @{{field[:name].id}} : {{field[:type].id}},
                       {% end %})
          # No need to call super(@span) - we handle span directly
        end
        
        # Visitor pattern support - optimized dispatch
        def accept(visitor)
          visitor.visit_{{name.id.underscore}}(self)
        end
        
        # Pre-computed children array for leaf nodes (empty and cached)
        {% if fields.all? { |f| ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol"].includes?(f[:type].id.stringify) } %}
          # This is a leaf node - return empty array without allocation
          @@empty_children = [] of Node
          
          def children : Array(Node)
            @@empty_children
          end
          
          def leaf? : Bool
            true
          end
          
          def depth : Int32
            0
          end
          
          def node_count : Int32
            1
          end
        {% else %}
          # Extract child nodes for traversal (regular implementation)
          def children : Array(Node)
            result = [] of Node
            {% for field in fields %}
              {% field_type = field[:type].id.stringify %}
              
              # List of known non-node types
              {% non_node_types = ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol", "Nil"] %}
              {% is_array = field_type.starts_with?("Array(") && field_type.ends_with?(")") %}
              
              {% if field[:optional] %}
                # Handle optional types
                {% if field_type.ends_with?("?") %}
                  {% base_type = field_type[0..-2] %}
                {% elsif field_type.includes?(" | ::Nil") %}
                  {% base_type = field_type.split(" | ::Nil")[0] %}
                {% elsif field_type.includes?(" | Nil") %}
                  {% base_type = field_type.split(" | Nil")[0] %}
                {% else %}
                  {% base_type = field_type %}
                {% end %}
                
                {% is_string_array = base_type == "Array(String)" %}
                {% is_basic = non_node_types.includes?(base_type) || is_string_array %}
                
                {% unless is_basic %}
                  if node = @{{field[:name].id}}
                    result << node
                  end
                {% end %}
                
              {% elsif is_array %}
                # Handle arrays
                {% inner_type = field_type[6..-2] %}
                {% is_array_of_basic = non_node_types.any? { |t| inner_type == t || inner_type == "#{t}?" } %}
                
                {% unless is_array_of_basic %}
                  result.concat(@{{field[:name].id}})
                {% end %}
                
              {% else %}
                # Handle regular fields
                {% is_basic_type = non_node_types.includes?(field_type) %}
                {% is_union_with_nil = field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil") %}
                
                {% unless is_basic_type || is_union_with_nil %}
                  result << @{{field[:name].id}}
                {% end %}
              {% end %}
            {% end %}
            result
          end
        {% end %}
        
        # Optimized equality comparison with short-circuit evaluation
        def ==(other : self) : Bool
          # Quick reference check
          return true if same?(other)
          
          # Span comparison first (most likely to differ)
          return false unless @span == other.span
          
          # Field comparison in order of likelihood to differ
          {% for field in fields %}
            return false unless @{{field[:name].id}} == other.{{field[:name].id}}
          {% end %}
          
          true
        end
        
        # Type-safe equality for different node types
        def ==(other) : Bool
          false
        end
        
        # Optimized clone - direct construction
        def clone : self
          {{name}}.new(
            @span,
            {% for field in fields %}
              {% field_type = field[:type].id.stringify %}
              
              # List of known non-node types
              {% non_node_types = ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol", "Nil"] %}
              {% is_array = field_type.starts_with?("Array(") && field_type.ends_with?(")") %}
              
              {% if field[:optional] %}
                {% if field_type.ends_with?("?") %}
                  {% base_type = field_type[0..-2] %}
                {% else %}
                  {% base_type = field_type %}
                {% end %}
                
                {% is_string_array = base_type == "Array(String)" %}
                {% is_basic = non_node_types.includes?(base_type) || is_string_array %}
                
                {% if is_basic %}
                  @{{field[:name].id}},
                {% else %}
                  @{{field[:name].id}}.try(&.clone),
                {% end %}
                
              {% elsif is_array %}
                {% inner_type = field_type[6..-2] %}
                {% is_array_of_basic = non_node_types.any? { |t| inner_type == t || inner_type == "#{t}?" } %}
                
                {% if is_array_of_basic %}
                  @{{field[:name].id}}.dup,
                {% else %}
                  @{{field[:name].id}}.map(&.clone),
                {% end %}
                
              {% else %}
                {% is_basic_type = non_node_types.includes?(field_type) %}
                {% is_union_with_nil = field_type.includes?(" | ::Nil") || field_type.includes?(" | Nil") %}
                
                {% if is_basic_type || is_union_with_nil %}
                  @{{field[:name].id}},
                {% else %}
                  @{{field[:name].id}}.clone,
                {% end %}
              {% end %}
            {% end %}
          )
        end
        
        # Optimized string representation
        def to_s(io : IO) : Nil
          io << {{name.stringify}}
          {% if fields.size > 0 %}
            io << "("
            {% for field, index in fields %}
              {% if index > 0 %}
                io << ", "
              {% end %}
              @{{field[:name].id}}.to_s(io)
            {% end %}
            io << ")"
          {% end %}
        end
        
        # Optimized find operations for leaf nodes
        {% if fields.all? { |f| ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol"].includes?(f[:type].id.stringify) } %}
          def find_all(type : T.class) : Array(T) forall T
            if self.is_a?(T)
              [self.as(T)]
            else
              [] of T
            end
          end
          
          def find_first(type : T.class) : T? forall T
            if self.is_a?(T)
              self.as(T)
            else
              nil
            end
          end
          
          def contains?(type : T.class) : Bool forall T
            self.is_a?(T)
          end
        {% end %}
      end
    end
  end
end