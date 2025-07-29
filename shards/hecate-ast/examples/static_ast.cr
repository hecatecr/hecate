require "../src/hecate-ast"
require "hecate-core"

# Static AST example demonstrating:
# - Manual AST node definition using Crystal classes
# - Type-safe AST construction
# - Visitor pattern implementation
# - AST transformation and analysis

# Define AST nodes manually (without the DSL)
module StaticASTExample
  # Base class for all AST nodes
  abstract class ASTNode < Hecate::AST::Node
    # Accept method for visitor pattern
    abstract def accept(visitor)
  end

  # Expression nodes
  abstract class Expr < ASTNode
  end

  # Statement nodes
  abstract class Stmt < ASTNode
  end

  # Program node - root of the AST
  class Program < ASTNode
    property imports : Array(Import)
    property declarations : Array(Declaration)

    def initialize(@span : Hecate::Core::Span, @imports = [] of Import, @declarations = [] of Declaration)
    end

    def accept(visitor)
      visitor.visit_program(self)
    end
  end

  # Import statement
  class Import < Stmt
    property module_name : String
    property alias_name : String?

    def initialize(@span : Hecate::Core::Span, @module_name : String, @alias_name : String? = nil)
    end

    def accept(visitor)
      visitor.visit_import(self)
    end
  end

  # Declaration types
  abstract class Declaration < Stmt
  end

  # Function declaration
  class FunctionDecl < Declaration
    property name : String
    property params : Array(Parameter)
    property return_type : TypeAnnotation?
    property body : Block

    def initialize(@span : Hecate::Core::Span, @name : String, @params : Array(Parameter),
                   @return_type : TypeAnnotation?, @body : Block)
    end

    def accept(visitor)
      visitor.visit_function_decl(self)
    end
  end

  # Class declaration
  class ClassDecl < Declaration
    property name : String
    property superclass : String?
    property members : Array(ClassMember)

    def initialize(@span : Hecate::Core::Span, @name : String,
                   @superclass : String?, @members : Array(ClassMember))
    end

    def accept(visitor)
      visitor.visit_class_decl(self)
    end
  end

  # Class member (field or method)
  abstract class ClassMember < ASTNode
  end

  class Field < ClassMember
    property name : String
    property type : TypeAnnotation
    property initial_value : Expr?

    def initialize(@span : Hecate::Core::Span, @name : String,
                   @type : TypeAnnotation, @initial_value : Expr? = nil)
    end

    def accept(visitor)
      visitor.visit_field(self)
    end
  end

  class Method < ClassMember
    property name : String
    property params : Array(Parameter)
    property return_type : TypeAnnotation?
    property body : Block

    def initialize(@span : Hecate::Core::Span, @name : String, @params : Array(Parameter),
                   @return_type : TypeAnnotation?, @body : Block)
    end

    def accept(visitor)
      visitor.visit_method(self)
    end
  end

  # Parameter
  class Parameter < ASTNode
    property name : String
    property type : TypeAnnotation

    def initialize(@span : Hecate::Core::Span, @name : String, @type : TypeAnnotation)
    end

    def accept(visitor)
      visitor.visit_parameter(self)
    end
  end

  # Type annotation
  class TypeAnnotation < ASTNode
    property name : String
    property type_args : Array(TypeAnnotation)

    def initialize(@span : Hecate::Core::Span, @name : String, @type_args = [] of TypeAnnotation)
    end

    def accept(visitor)
      visitor.visit_type_annotation(self)
    end
  end

  # Statement types
  class Block < Stmt
    property statements : Array(Stmt)

    def initialize(@span : Hecate::Core::Span, @statements : Array(Stmt))
    end

    def accept(visitor)
      visitor.visit_block(self)
    end
  end

  class ExprStmt < Stmt
    property expr : Expr

    def initialize(@span : Hecate::Core::Span, @expr : Expr)
    end

    def accept(visitor)
      visitor.visit_expr_stmt(self)
    end
  end

  class Return < Stmt
    property value : Expr?

    def initialize(@span : Hecate::Core::Span, @value : Expr? = nil)
    end

    def accept(visitor)
      visitor.visit_return(self)
    end
  end

  # Expression types
  class Identifier < Expr
    property name : String

    def initialize(@span : Hecate::Core::Span, @name : String)
    end

    def accept(visitor)
      visitor.visit_identifier(self)
    end
  end

  class IntegerLiteral < Expr
    property value : Int64

    def initialize(@span : Hecate::Core::Span, @value : Int64)
    end

    def accept(visitor)
      visitor.visit_integer_literal(self)
    end
  end

  class StringLiteral < Expr
    property value : String

    def initialize(@span : Hecate::Core::Span, @value : String)
    end

    def accept(visitor)
      visitor.visit_string_literal(self)
    end
  end

  class BinaryOp < Expr
    property left : Expr
    property operator : String
    property right : Expr

    def initialize(@span : Hecate::Core::Span, @left : Expr, @operator : String, @right : Expr)
    end

    def accept(visitor)
      visitor.visit_binary_op(self)
    end
  end

  class Call < Expr
    property callee : Expr
    property arguments : Array(Expr)

    def initialize(@span : Hecate::Core::Span, @callee : Expr, @arguments : Array(Expr))
    end

    def accept(visitor)
      visitor.visit_call(self)
    end
  end

  # Visitor interface
  abstract class Visitor
    abstract def visit_program(node : Program)
    abstract def visit_import(node : Import)
    abstract def visit_function_decl(node : FunctionDecl)
    abstract def visit_class_decl(node : ClassDecl)
    abstract def visit_field(node : Field)
    abstract def visit_method(node : Method)
    abstract def visit_parameter(node : Parameter)
    abstract def visit_type_annotation(node : TypeAnnotation)
    abstract def visit_block(node : Block)
    abstract def visit_expr_stmt(node : ExprStmt)
    abstract def visit_return(node : Return)
    abstract def visit_identifier(node : Identifier)
    abstract def visit_integer_literal(node : IntegerLiteral)
    abstract def visit_string_literal(node : StringLiteral)
    abstract def visit_binary_op(node : BinaryOp)
    abstract def visit_call(node : Call)
  end

  # Pretty printer visitor
  class PrettyPrinter < Visitor
    def initialize
      @indent = 0
      @output = [] of String
    end

    def result
      @output.join("\n")
    end

    private def write(text : String)
      @output << ("  " * @indent + text)
    end

    private def indent(&)
      @indent += 1
      yield
      @indent -= 1
    end

    def visit_program(node : Program)
      node.imports.each { |import| import.accept(self) }
      write("") if node.imports.any?
      node.declarations.each { |decl| decl.accept(self) }
    end

    def visit_import(node : Import)
      if alias_name = node.alias_name
        write("import #{node.module_name} as #{alias_name}")
      else
        write("import #{node.module_name}")
      end
    end

    def visit_function_decl(node : FunctionDecl)
      params = node.params.map do |p|
        "#{p.name}: #{p.type.name}"
      end.join(", ")

      return_type = node.return_type ? " -> #{node.return_type.name}" : ""
      write("function #{node.name}(#{params})#{return_type} {")
      indent { node.body.accept(self) }
      write("}")
    end

    def visit_class_decl(node : ClassDecl)
      extends = node.superclass ? " extends #{node.superclass}" : ""
      write("class #{node.name}#{extends} {")
      indent do
        node.members.each { |member| member.accept(self) }
      end
      write("}")
    end

    def visit_field(node : Field)
      initial = node.initial_value ? " = #{node.initial_value}" : ""
      write("field #{node.name}: #{node.type.name}#{initial}")
    end

    def visit_method(node : Method)
      params = node.params.map do |p|
        "#{p.name}: #{p.type.name}"
      end.join(", ")

      return_type = node.return_type ? " -> #{node.return_type.name}" : ""
      write("method #{node.name}(#{params})#{return_type} {")
      indent { node.body.accept(self) }
      write("}")
    end

    def visit_parameter(node : Parameter)
      # Handled in function/method
    end

    def visit_type_annotation(node : TypeAnnotation)
      # Handled inline
    end

    def visit_block(node : Block)
      node.statements.each { |stmt| stmt.accept(self) }
    end

    def visit_expr_stmt(node : ExprStmt)
      write(expr_to_string(node.expr))
    end

    def visit_return(node : Return)
      value = node.value ? " #{expr_to_string(node.value)}" : ""
      write("return#{value}")
    end

    def visit_identifier(node : Identifier)
      # Handled inline
    end

    def visit_integer_literal(node : IntegerLiteral)
      # Handled inline
    end

    def visit_string_literal(node : StringLiteral)
      # Handled inline
    end

    def visit_binary_op(node : BinaryOp)
      # Handled inline
    end

    def visit_call(node : Call)
      # Handled inline
    end

    private def expr_to_string(expr : Expr) : String
      case expr
      when Identifier
        expr.name
      when IntegerLiteral
        expr.value.to_s
      when StringLiteral
        expr.value.inspect
      when BinaryOp
        "#{expr_to_string(expr.left)} #{expr.operator} #{expr_to_string(expr.right)}"
      when Call
        args = expr.arguments.map { |arg| expr_to_string(arg) }.join(", ")
        "#{expr_to_string(expr.callee)}(#{args})"
      else
        "???"
      end
    end
  end

  # Symbol collector visitor
  class SymbolCollector < Visitor
    property symbols : Set(String)

    def initialize
      @symbols = Set(String).new
    end

    def visit_program(node : Program)
      node.imports.each { |import| import.accept(self) }
      node.declarations.each { |decl| decl.accept(self) }
    end

    def visit_import(node : Import)
      @symbols << (node.alias_name || node.module_name)
    end

    def visit_function_decl(node : FunctionDecl)
      @symbols << node.name
      node.params.each { |param| param.accept(self) }
      node.body.accept(self)
    end

    def visit_class_decl(node : ClassDecl)
      @symbols << node.name
      node.members.each { |member| member.accept(self) }
    end

    def visit_field(node : Field)
      @symbols << node.name
    end

    def visit_method(node : Method)
      @symbols << node.name
      node.params.each { |param| param.accept(self) }
      node.body.accept(self)
    end

    def visit_parameter(node : Parameter)
      @symbols << node.name
    end

    def visit_type_annotation(node : TypeAnnotation)
      # Not collecting type names in this example
    end

    def visit_block(node : Block)
      node.statements.each { |stmt| stmt.accept(self) }
    end

    def visit_expr_stmt(node : ExprStmt)
      node.expr.accept(self)
    end

    def visit_return(node : Return)
      node.value.try &.accept(self)
    end

    def visit_identifier(node : Identifier)
      # Don't collect identifier references, only declarations
    end

    def visit_integer_literal(node : IntegerLiteral)
      # Nothing to collect
    end

    def visit_string_literal(node : StringLiteral)
      # Nothing to collect
    end

    def visit_binary_op(node : BinaryOp)
      node.left.accept(self)
      node.right.accept(self)
    end

    def visit_call(node : Call)
      node.callee.accept(self)
      node.arguments.each { |arg| arg.accept(self) }
    end
  end
end

# Example usage
def main
  # Create a dummy span for our examples
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("example.lang", "dummy content")
  dummy_span = Hecate::Core::Span.new(source_id, 0_u32, 0_u32)

  # Build an example AST manually
  # This represents a simple program:
  #
  # import std.io
  #
  # class Calculator {
  #   field result: int
  #
  #   method add(a: int, b: int) -> int {
  #     return a + b
  #   }
  # }
  #
  # function main() {
  #   calc.add(10, 20)
  # }

  # Type annotations
  int_type = StaticASTExample::TypeAnnotation.new(dummy_span, "int")

  # Build the program
  program = StaticASTExample::Program.new(
    dummy_span,
    imports: [
      StaticASTExample::Import.new(dummy_span, "std.io"),
    ],
    declarations: [
      # Calculator class
      StaticASTExample::ClassDecl.new(
        dummy_span,
        "Calculator",
        nil, # no superclass
        [
        # Field
        StaticASTExample::Field.new(
          dummy_span,
          "result",
          int_type,
          StaticASTExample::IntegerLiteral.new(dummy_span, 0_i64)
        ),

        # Method
        StaticASTExample::Method.new(
          dummy_span,
          "add",
          [
            StaticASTExample::Parameter.new(dummy_span, "a", int_type),
            StaticASTExample::Parameter.new(dummy_span, "b", int_type),
          ],
          int_type, # return type
          StaticASTExample::Block.new(
          dummy_span,
          [
            StaticASTExample::Return.new(
              dummy_span,
              StaticASTExample::BinaryOp.new(
                dummy_span,
                StaticASTExample::Identifier.new(dummy_span, "a"),
                "+",
                StaticASTExample::Identifier.new(dummy_span, "b")
              )
            ),
          ]
        )
        ),
      ]
      ),

      # Main function
      StaticASTExample::FunctionDecl.new(
        dummy_span,
        "main",
        [] of StaticASTExample::Parameter,
        nil, # no return type
        StaticASTExample::Block.new(
        dummy_span,
        [
          StaticASTExample::ExprStmt.new(
            dummy_span,
            StaticASTExample::Call.new(
              dummy_span,
              StaticASTExample::Identifier.new(dummy_span, "calc.add"),
              [
                StaticASTExample::IntegerLiteral.new(dummy_span, 10_i64),
                StaticASTExample::IntegerLiteral.new(dummy_span, 20_i64),
              ]
            )
          ),
        ]
      )
      ),
    ]
  )

  puts "=== Static AST Example ==="

  # Pretty print the AST
  puts "\n--- Pretty Printed Program ---"
  printer = StaticASTExample::PrettyPrinter.new
  program.accept(printer)
  puts printer.result

  # Collect symbols
  puts "\n--- Symbol Collection ---"
  collector = StaticASTExample::SymbolCollector.new
  program.accept(collector)
  puts "Declared symbols: #{collector.symbols.to_a.sort.join(", ")}"

  # Demonstrate type-safe construction
  puts "\n--- Type Safety ---"
  puts "Program has #{program.imports.size} imports"
  puts "Program has #{program.declarations.size} declarations"

  program.declarations.each do |decl|
    case decl
    when StaticASTExample::ClassDecl
      puts "  Class '#{decl.name}' with #{decl.members.size} members"
    when StaticASTExample::FunctionDecl
      puts "  Function '#{decl.name}' with #{decl.params.size} parameters"
    end
  end

  # Show AST node information
  puts "\n--- AST Node Information ---"
  puts "Root span: #{program.span}"
  puts "Node class: #{program.class}"

  # Find specific nodes
  if first_class = program.declarations.find(&.is_a?(StaticASTExample::ClassDecl))
    class_decl = first_class.as(StaticASTExample::ClassDecl)
    puts "\nFirst class: #{class_decl.name}"

    if first_method = class_decl.members.find(&.is_a?(StaticASTExample::Method))
      method = first_method.as(StaticASTExample::Method)
      puts "  First method: #{method.name}"
      puts "  Parameters: #{method.params.map(&.name).join(", ")}"
    end
  end
end

main
