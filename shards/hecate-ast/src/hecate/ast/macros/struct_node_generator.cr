module Hecate::AST
  module Macros
    # Generate struct-based leaf nodes for memory optimization
    # These structs implement the Node interface but use value semantics
    # for better memory efficiency and cache locality
    
    macro generate_struct_node(name, parent, fields)
      # Generate the struct implementation
      struct {{name}}Struct
        # Generate getters for each field
        {% for field in fields %}
          getter {{field[:name].id}} : {{field[:type].id}}
        {% end %}
        
        getter span : Hecate::Core::Span
        
        # Constructor with span and all fields
        def initialize(@span : Hecate::Core::Span,
                       {% for field in fields %}
                         @{{field[:name].id}} : {{field[:type].id}},
                       {% end %})
        end
        
        # Struct nodes are always leaves (no children)
        def children : Array(::Hecate::AST::Node)
          [] of ::Hecate::AST::Node
        end
        
        # Equality comparison for structs
        def ==(other : self) : Bool
          return false unless @span == other.span
          {% for field in fields %}
            return false unless @{{field[:name].id}} == other.{{field[:name].id}}
          {% end %}
          true
        end
        
        # Clone for structs is just a copy (they're immutable)
        def clone : self
          {{name}}Struct.new(
            @span,
            {% for field in fields %}
              @{{field[:name].id}},
            {% end %}
          )
        end
        
        # Visitor pattern support - struct accepts visitor directly
        def accept(visitor)
          visitor.visit_{{name.id.underscore}}(self)
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
        
        # Implement Node interface methods that structs need
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
        
        # Parent tracking (structs don't need complex hierarchies)
        property parent : ::Hecate::AST::Node?
        
        def ancestors : Array(::Hecate::AST::Node)
          nodes = [] of ::Hecate::AST::Node
          current = parent
          
          while current
            nodes << current
            current = current.parent
          end
          
          nodes
        end
      end
      
      # Generate a wrapper class that implements the full Node interface
      # This allows struct nodes to be used polymorphically when needed
      class {{name}}Wrapper < {{parent}}
        getter inner : {{name}}Struct
        
        def initialize(@inner : {{name}}Struct)
          super(@inner.span)
        end
        
        # Delegate all field access to the inner struct
        {% for field in fields %}
          def {{field[:name].id}}
            @inner.{{field[:name].id}}
          end
        {% end %}
        
        # Delegate Node interface methods
        def accept(visitor)
          visitor.visit_{{name.id.underscore}}(@inner)
        end
        
        def children : Array(Node)
          @inner.children
        end
        
        def ==(other : self) : Bool
          @inner == other.inner
        end
        
        def ==(other : {{name}}Struct) : Bool
          @inner == other
        end
        
        def clone : self
          {{name}}Wrapper.new(@inner.clone)
        end
        
        def to_s(io : IO) : Nil
          @inner.to_s(io)
        end
        
        # Forward all Node methods to the struct
        def leaf? : Bool
          @inner.leaf?
        end
        
        def depth : Int32
          @inner.depth
        end
        
        def node_count : Int32
          @inner.node_count
        end
        
        def find_all(type : T.class) : Array(T) forall T
          @inner.find_all(type)
        end
        
        def find_first(type : T.class) : T? forall T
          @inner.find_first(type)
        end
        
        def contains?(type : T.class) : Bool forall T
          @inner.contains?(type)
        end
      end
      
      # Create a type alias that defaults to the struct but can be wrapped
      alias {{name}} = {{name}}Struct
      
      # Factory methods for creating nodes
      module {{name}}Factory
        extend self
        
        # Create a struct node (most memory efficient)
        def create_struct(span : Hecate::Core::Span,
                         {% for field in fields %}
                           {{field[:name].id}} : {{field[:type].id}},
                         {% end %}) : {{name}}Struct
          {{name}}Struct.new(
            span,
            {% for field in fields %}
              {{field[:name].id}},
            {% end %}
          )
        end
        
        # Create a wrapped node (for polymorphic usage)
        def create_wrapped(span : Hecate::Core::Span,
                          {% for field in fields %}
                            {{field[:name].id}} : {{field[:type].id}},
                          {% end %}) : {{name}}Wrapper
          struct_node = create_struct(
            span,
            {% for field in fields %}
              {{field[:name].id}},
            {% end %}
          )
          {{name}}Wrapper.new(struct_node)
        end
        
        # Smart factory that chooses based on usage context
        # Defaults to struct for direct usage, wrapper for polymorphic arrays
        def create(span : Hecate::Core::Span,
                  {% for field in fields %}
                    {{field[:name].id}} : {{field[:type].id}},
                  {% end %}) : {{name}}Struct
          create_struct(
            span,
            {% for field in fields %}
              {{field[:name].id}},
            {% end %}
          )
        end
      end
      
      # Extend the struct to include factory methods directly
      struct {{name}}Struct
        # Convenient constructor that matches the old class interface
        def self.new(span : Hecate::Core::Span,
                     {% for field in fields %}
                       {{field[:name].id}} : {{field[:type].id}},
                     {% end %})
          {{name}}Factory.create_struct(
            span,
            {% for field in fields %}
              {{field[:name].id}},
            {% end %}
          )
        end
        
        # Convert to wrapper when polymorphism is needed
        def to_wrapper : {{name}}Wrapper
          {{name}}Wrapper.new(self)
        end
        
        # Check if this struct is compatible with Node interface
        def is_node? : Bool
          true
        end
      end
    end
  end
end