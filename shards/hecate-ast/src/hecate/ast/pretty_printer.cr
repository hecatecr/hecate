require "json"

module Hecate::AST
  # Pretty printer for AST nodes that produces human-readable indented output
  class PrettyPrinter
    private getter indent_size : Int32
    private getter compact : Bool

    def initialize(@indent_size : Int32 = 2, @compact : Bool = false)
    end

    def print(node : Node) : String
      io = IO::Memory.new
      print_node(io, node, 0)
      io.to_s
    end

    private def print_node(io : IO, node : Node, indent : Int32) : Nil
      print_indent(io, indent) unless @compact

      # Print node type
      node_type = node.class.name.split("::").last
      io << node_type

      # Get simple fields
      fields = extract_simple_fields(node)

      # Get children
      children = node.children

      # Print based on what we have
      if fields.empty? && children.empty?
        # Nothing more to print
      elsif !fields.empty? && children.empty?
        # Only fields
        print_fields(io, fields)
      elsif fields.empty? && !children.empty?
        # Only children
        if @compact
          print_children_compact(io, children)
        else
          print_children_indented(io, children, indent)
        end
      else
        # Both fields and children
        print_fields(io, fields)
        if @compact
          # In compact mode, children are part of the same parentheses
          children.each do |child|
            io << ", "
            print_node(io, child, 0)
          end
        else
          # In indented mode, use braces for children
          io << " {"
          children.each do |child|
            io.puts
            print_node(io, child, indent + @indent_size)
          end
          io.puts
          print_indent(io, indent)
          io << "}"
        end
      end
    end

    private def print_indent(io : IO, indent : Int32) : Nil
      io << " " * indent
    end

    private def print_fields(io : IO, fields : Array({String, String})) : Nil
      io << "("
      fields.each_with_index do |(name, value), i|
        io << ", " if i > 0
        io << name << ": " << value
      end
      io << ")"
    end

    private def print_children_compact(io : IO, children : Array(Node)) : Nil
      io << "("
      children.each_with_index do |child, i|
        io << ", " if i > 0
        print_node(io, child, 0)
      end
      io << ")"
    end

    private def print_children_indented(io : IO, children : Array(Node), indent : Int32) : Nil
      io << " {"
      children.each do |child|
        io.puts
        print_node(io, child, indent + @indent_size)
      end
      io.puts
      print_indent(io, indent)
      io << "}"
    end

    # Extract simple fields from a node
    private def extract_simple_fields(node : Node)
      fields = [] of {String, String}

      # Check for common field names using macros
      {% for field in [:value, :name, :operator, :kind, :text, :type_name] %}
        if node.responds_to?({{field}})
          value = node.{{field.id}}
          # Skip node values - they should be in children
          unless value.is_a?(Node)
            # Convert all values to strings for display
            formatted = format_field_value(value)
            fields << { {{field.id.stringify}}, formatted } unless formatted.empty?
          end
        end
      {% end %}

      fields
    end

    private def format_field_value(value) : String
      case value
      when String
        value.inspect
      when Nil
        "nil"
      when Node
        # Don't include nodes as simple fields - they should be in children
        return ""
      else
        value.to_s
      end
    end
  end

  # S-expression printer for AST nodes
  class SExpPrinter
    def print(node : Node) : String
      String.build do |io|
        print_node(io, node)
      end
    end

    private def print_node(io : IO, node : Node) : Nil
      node_class = node.class.name.split("::").last.underscore

      io << '('
      io << node_class

      # Print simple fields first
      {% for field in [:value, :name, :operator, :kind, :text] %}
        if node.responds_to?({{field}})
          io << ' '
          print_value(io, node.{{field.id}})
        end
      {% end %}

      # Then print children
      node.children.each do |child|
        io << ' '
        print_node(io, child)
      end

      io << ')'
    end

    private def print_value(io : IO, value) : Nil
      case value
      when String
        io << '"'
        value.each_char do |char|
          case char
          when '"'  then io << "\\\""
          when '\\' then io << "\\\\"
          when '\n' then io << "\\n"
          when '\r' then io << "\\r"
          when '\t' then io << "\\t"
          else           io << char
          end
        end
        io << '"'
      when Nil
        io << "nil"
      when Bool
        io << (value ? "#t" : "#f")
      else
        io << value.to_s
      end
    end
  end

  # JSON serialization support for AST nodes
  module JSONSerializer
    # Serialize any AST node to JSON
    def self.to_json(node : Node, json : JSON::Builder) : Nil
      json.object do
        json.field "type", node.class.name.split("::").last
        json.field "span" do
          json.object do
            json.field "source_id", node.span.source_id
            json.field "start_byte", node.span.start_byte
            json.field "end_byte", node.span.end_byte
          end
        end

        # Serialize node-specific fields
        {% for field in [:value, :name, :operator, :kind, :text, :type_name] %}
          if node.responds_to?({{field}})
            value = node.{{field.id}}
            unless value.nil?
              json.field {{field.id.stringify}}, value
            end
          end
        {% end %}

        # Serialize children if any
        children = node.children
        unless children.empty?
          json.field "children" do
            json.array do
              children.each do |child|
                to_json(child, json)
              end
            end
          end
        end
      end
    end
  end

  # Tree visualization utilities
  class TreePrinter
    def print(node : Node, io : IO = STDOUT) : Nil
      print_tree(io, node, "", true)
    end

    private def print_tree(io : IO, node : Node, prefix : String, is_last : Bool) : Nil
      # Print current node
      io << prefix
      io << (is_last ? "└── " : "├── ")
      io << node.class.name.split("::").last

      # Add simple field info if available
      if node.responds_to?(:value) && !node.value.is_a?(Node)
        io << "(#{node.value.inspect})"
      elsif node.responds_to?(:name) && node.name.is_a?(String)
        io << "(#{node.name.inspect})"
      end

      io << " [#{node.span.start_byte}-#{node.span.end_byte}]"
      io.puts

      # Print children
      children = node.children
      children.each_with_index do |child, i|
        child_prefix = prefix + (is_last ? "    " : "│   ")
        is_last_child = (i == children.size - 1)
        print_tree(io, child, child_prefix, is_last_child)
      end
    end
  end

  # Extension methods for Node class
  abstract class Node
    # Pretty print this node
    def pretty_print(indent_size : Int32 = 2, compact : Bool = false) : String
      PrettyPrinter.new(indent_size, compact).print(self)
    end

    # Convert to S-expression
    def to_sexp : String
      SExpPrinter.new.print(self)
    end

    # Convert to JSON
    def to_json(json : JSON::Builder) : Nil
      JSONSerializer.to_json(self, json)
    end

    # Convert to JSON string
    def to_json : String
      JSON.build do |json|
        to_json(json)
      end
    end

    # Print tree visualization
    def print_tree(io : IO = STDOUT) : Nil
      TreePrinter.new.print(self, io)
    end

    # Get a compact single-line representation
    def to_compact_s : String
      PrettyPrinter.new(compact: true).print(self)
    end

    # Get source snippet with context
    def source_snippet(source : String, context_lines : Int32 = 2) : String?
      return nil if span.start_byte >= source.bytesize

      # Simple line extraction
      lines = source.lines(chomp: false)
      line_starts = [] of Int32
      pos = 0

      lines.each do |line|
        line_starts << pos
        pos += line.bytesize
      end

      # Find start and end lines
      start_line = 0
      end_line = 0

      line_starts.each_with_index do |line_start, i|
        if line_start <= span.start_byte && (i == line_starts.size - 1 || line_starts[i + 1] > span.start_byte)
          start_line = i
        end
        if line_start <= span.end_byte && (i == line_starts.size - 1 || line_starts[i + 1] > span.end_byte)
          end_line = i
        end
      end

      # Build snippet
      String.build do |io|
        first = Math.max(0, start_line - context_lines)
        last = Math.min(lines.size - 1, end_line + context_lines)

        (first..last).each do |i|
          line = lines[i]
          is_target = i >= start_line && i <= end_line

          io << (i + 1).to_s << ":"
          io << " " * (4 - (i + 1).to_s.size)
          io << (is_target ? "│ " : "  ")
          io << line
        end
      end
    end
  end
end
