require "../node_pool"

module Hecate::AST
  module Macros
    # Generate memory-optimized node classes with object pooling
    # Combines optimized node layout with pooling for common literal values
    macro generate_pooled_node_class(name, parent, fields)
      class {{name}} < {{parent}}
        # Use explicit instance variable declarations for better memory layout
        {% for field in fields %}
          @{{field[:name].id}} : {{field[:type].id}}
          
          def {{field[:name].id}} : {{field[:type].id}}
            @{{field[:name].id}}
          end
        {% end %}
        
        # Private constructor - only used by pool factory
        private def initialize(@span : Hecate::Core::Span,
                              {% for field in fields %}
                                @{{field[:name].id}} : {{field[:type].id}},
                              {% end %})
        end
        
        # Pool-aware factory method
        def self.new(span : Hecate::Core::Span,
                     {% for field in fields %}
                       {{field[:name].id}} : {{field[:type].id}},
                     {% end %}) : self
          {% if fields.size == 1 %}
            {% field = fields[0] %}
            {% field_type = field[:type].id.stringify %}
            
            # Check if this is a poolable type
            {% if field_type == "Int32" %}
              # Pool integer literals
              factory = ->(s : Hecate::Core::Span, v : Int32) {
                allocate.tap do |node|
                  node.initialize(s, v)
                end.as(::Hecate::AST::Node)
              }
              ::Hecate::AST::NodePool.get_int_lit(span, {{field[:name].id}}, factory).as(self)
              
            {% elsif field_type == "Bool" %}
              # Pool boolean literals
              factory = ->(s : Hecate::Core::Span, v : Bool) {
                allocate.tap do |node|
                  node.initialize(s, v)
                end.as(::Hecate::AST::Node)
              }
              ::Hecate::AST::NodePool.get_bool_lit(span, {{field[:name].id}}, factory).as(self)
              
            {% elsif field_type == "String" && name.stringify.ends_with?("Lit") %}
              # Pool string literals
              factory = ->(s : Hecate::Core::Span, v : String) {
                allocate.tap do |node|
                  node.initialize(s, v)
                end.as(::Hecate::AST::Node)
              }
              ::Hecate::AST::NodePool.get_string_lit(span, {{field[:name].id}}, factory).as(self)
              
            {% elsif field_type == "String" && (name.stringify.includes?("Id") || name.stringify.includes?("Name")) %}
              # Pool identifiers
              factory = ->(s : Hecate::Core::Span, v : String) {
                allocate.tap do |node|
                  node.initialize(s, v)
                end.as(::Hecate::AST::Node)
              }
              ::Hecate::AST::NodePool.get_identifier(span, {{field[:name].id}}, factory).as(self)
              
            {% else %}
              # Not poolable - create directly
              allocate.tap do |node|
                node.initialize(span, {{field[:name].id}})
              end
            {% end %}
          {% else %}
            # Multi-field nodes are not pooled (too complex)
            allocate.tap do |node|
              node.initialize(
                span,
                {% for field in fields %}
                  {{field[:name].id}},
                {% end %}
              )
            end
          {% end %}
        end
        
        # Visitor pattern support
        def accept(visitor)
          visitor.visit_{{name.id.underscore}}(self)
        end
        
        # Optimized children array for leaf nodes
        {% if fields.all? { |f| ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol"].includes?(f[:type].id.stringify) } %}
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
        {% else %}
          # Regular children implementation for non-leaf nodes
          def children : Array(Node)
            result = [] of Node
            {% for field in fields %}
              {% field_type = field[:type].id.stringify %}
              
              {% non_node_types = ["String", "Int32", "Int64", "Float32", "Float64", "Bool", "Char", "Symbol", "Nil"] %}
              {% is_array = field_type.starts_with?("Array(") && field_type.ends_with?(")") %}
              
              {% if field[:optional] %}
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
                {% inner_type = field_type[6..-2] %}
                {% is_array_of_basic = non_node_types.any? { |t| inner_type == t || inner_type == "#{t}?" } %}
                
                {% unless is_array_of_basic %}
                  result.concat(@{{field[:name].id}})
                {% end %}
                
              {% else %}
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
        
        # Optimized equality comparison
        def ==(other : self) : Bool
          return true if same?(other)
          return false unless @span == other.span
          
          {% for field in fields %}
            return false unless @{{field[:name].id}} == other.{{field[:name].id}}
          {% end %}
          
          true
        end
        
        def ==(other) : Bool
          false
        end
        
        # Clone method - for pooled nodes, we often return the same instance
        # since they're immutable literals
        def clone : self
          {% if fields.size == 1 %}
            {% field = fields[0] %}
            {% field_type = field[:type].id.stringify %}
            
            # For poolable literals, cloning can return the same instance
            {% if ["Int32", "Bool", "String"].includes?(field_type) %}
              # Immutable literal - safe to return same instance
              self
            {% else %}
              # Create new instance for non-literals
              self.class.new(@span, @{{field[:name].id}})
            {% end %}
          {% else %}
            # Multi-field nodes need proper cloning
            self.class.new(
              @span,
              {% for field in fields %}
                {% field_type = field[:type].id.stringify %}
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
          {% end %}
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
      end
    end
  end
end
