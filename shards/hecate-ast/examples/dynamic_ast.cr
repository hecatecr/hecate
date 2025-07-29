require "../src/hecate-ast"
require "hecate-core"

# Dynamic AST example demonstrating:
# - Dynamic node definition using the DSL
# - Visitor pattern for traversing and transforming ASTs
# - Pattern matching on node types
# - AST construction and manipulation

module DynamicASTExample
  # Define a simple expression AST using the dynamic DSL
  module AST
    include Hecate::AST

    # Abstract base for all expressions
    abstract_node Expr

    # Literal values
    node IntLit < Expr, value : Int32
    node FloatLit < Expr, value : Float64
    node BoolLit < Expr, value : Bool
    node StringLit < Expr, value : String

    # Binary operations
    node Add < Expr, left : Expr, right : Expr
    node Sub < Expr, left : Expr, right : Expr
    node Mul < Expr, left : Expr, right : Expr
    node Div < Expr, left : Expr, right : Expr

    # Comparison operations
    node Eq < Expr, left : Expr, right : Expr
    node Lt < Expr, left : Expr, right : Expr

    # Logical operations
    node And < Expr, left : Expr, right : Expr
    node Or < Expr, left : Expr, right : Expr
    node Not < Expr, operand : Expr

    # Variable reference
    node Var < Expr, name : String

    # Let binding: let name = value in body
    node Let < Expr, name : String, value : Expr, body : Expr

    # If expression: if cond then then_expr else else_expr
    node If < Expr, cond : Expr, then_expr : Expr, else_expr : Expr

    # Finalize AST to generate visitors and type predicates
    finalize_ast IntLit, FloatLit, BoolLit, StringLit,
                 Add, Sub, Mul, Div,
                 Eq, Lt,
                 And, Or, Not,
                 Var, Let, If
  end

  # Example visitor: Pretty printer
  class PrettyPrinter < AST::Visitor(String)
    def initialize
      @indent = 0
    end

    def visit_int_lit(node : AST::IntLit) : String
      node.value.to_s
    end

    def visit_float_lit(node : AST::FloatLit) : String
      node.value.to_s
    end

    def visit_bool_lit(node : AST::BoolLit) : String
      node.value.to_s
    end

    def visit_string_lit(node : AST::StringLit) : String
      node.value.inspect
    end

    def visit_add(node : AST::Add) : String
      "(#{visit(node.left)} + #{visit(node.right)})"
    end

    def visit_sub(node : AST::Sub) : String
      "(#{visit(node.left)} - #{visit(node.right)})"
    end

    def visit_mul(node : AST::Mul) : String
      "(#{visit(node.left)} * #{visit(node.right)})"
    end

    def visit_div(node : AST::Div) : String
      "(#{visit(node.left)} / #{visit(node.right)})"
    end

    def visit_eq(node : AST::Eq) : String
      "(#{visit(node.left)} == #{visit(node.right)})"
    end

    def visit_lt(node : AST::Lt) : String
      "(#{visit(node.left)} < #{visit(node.right)})"
    end

    def visit_and(node : AST::And) : String
      "(#{visit(node.left)} && #{visit(node.right)})"
    end

    def visit_or(node : AST::Or) : String
      "(#{visit(node.left)} || #{visit(node.right)})"
    end

    def visit_not(node : AST::Not) : String
      "!#{visit(node.operand)}"
    end

    def visit_var(node : AST::Var) : String
      node.name
    end

    def visit_let(node : AST::Let) : String
      "let #{node.name} = #{visit(node.value)} in #{visit(node.body)}"
    end

    def visit_if(node : AST::If) : String
      "if #{visit(node.cond)} then #{visit(node.then_expr)} else #{visit(node.else_expr)}"
    end
  end

  # Example visitor: Type inference
  class TypeInferer < AST::Visitor(Symbol)
    def initialize
      @env = {} of String => Symbol
    end

    def visit_int_lit(node : AST::IntLit) : Symbol
      :int
    end

    def visit_float_lit(node : AST::FloatLit) : Symbol
      :float
    end

    def visit_bool_lit(node : AST::BoolLit) : Symbol
      :bool
    end

    def visit_string_lit(node : AST::StringLit) : Symbol
      :string
    end

    def visit_add(node : AST::Add) : Symbol
      infer_numeric_op(node.left, node.right)
    end

    def visit_sub(node : AST::Sub) : Symbol
      infer_numeric_op(node.left, node.right)
    end

    def visit_mul(node : AST::Mul) : Symbol
      infer_numeric_op(node.left, node.right)
    end

    def visit_div(node : AST::Div) : Symbol
      infer_numeric_op(node.left, node.right)
    end

    def visit_eq(node : AST::Eq) : Symbol
      visit(node.left)
      visit(node.right)
      :bool
    end

    def visit_lt(node : AST::Lt) : Symbol
      visit(node.left)
      visit(node.right)
      :bool
    end

    def visit_and(node : AST::And) : Symbol
      :bool
    end

    def visit_or(node : AST::Or) : Symbol
      :bool
    end

    def visit_not(node : AST::Not) : Symbol
      :bool
    end

    def visit_var(node : AST::Var) : Symbol
      @env[node.name]? || :unknown
    end

    def visit_let(node : AST::Let) : Symbol
      value_type = visit(node.value)
      old_binding = @env[node.name]?
      @env[node.name] = value_type
      result = visit(node.body)
      if old_binding
        @env[node.name] = old_binding
      else
        @env.delete(node.name)
      end
      result
    end

    def visit_if(node : AST::If) : Symbol
      visit(node.cond)
      then_type = visit(node.then_expr)
      else_type = visit(node.else_expr)
      # Simple type unification
      if then_type == else_type
        then_type
      else
        :unknown
      end
    end

    private def infer_numeric_op(left : AST::Expr, right : AST::Expr) : Symbol
      left_type = visit(left)
      right_type = visit(right)
      
      if left_type == :float || right_type == :float
        :float
      elsif left_type == :int && right_type == :int
        :int
      else
        :unknown
      end
    end
  end

  # Example transformer: Constant folding
  class ConstantFolder < AST::Transformer
    def visit_add(node : AST::Add) : AST::Expr
      left = visit(node.left)
      right = visit(node.right)

      case {left, right}
      when {AST::IntLit, AST::IntLit}
        AST::IntLit.new(node.span, left.value + right.value)
      when {AST::FloatLit, AST::FloatLit}
        AST::FloatLit.new(node.span, left.value + right.value)
      else
        AST::Add.new(node.span, left, right)
      end
    end

    def visit_sub(node : AST::Sub) : AST::Expr
      left = visit(node.left)
      right = visit(node.right)

      case {left, right}
      when {AST::IntLit, AST::IntLit}
        AST::IntLit.new(node.span, left.value - right.value)
      when {AST::FloatLit, AST::FloatLit}
        AST::FloatLit.new(node.span, left.value - right.value)
      else
        AST::Sub.new(node.span, left, right)
      end
    end

    def visit_mul(node : AST::Mul) : AST::Expr
      left = visit(node.left)
      right = visit(node.right)

      case {left, right}
      when {AST::IntLit, AST::IntLit}
        AST::IntLit.new(node.span, left.value * right.value)
      when {AST::FloatLit, AST::FloatLit}
        AST::FloatLit.new(node.span, left.value * right.value)
      else
        AST::Mul.new(node.span, left, right)
      end
    end

    def visit_and(node : AST::And) : AST::Expr
      left = visit(node.left)
      right = visit(node.right)

      case {left, right}
      when {AST::BoolLit, AST::BoolLit}
        AST::BoolLit.new(node.span, left.value && right.value)
      else
        AST::And.new(node.span, left, right)
      end
    end

    def visit_not(node : AST::Not) : AST::Expr
      operand = visit(node.operand)

      if operand.is_a?(AST::BoolLit)
        AST::BoolLit.new(node.span, !operand.value)
      else
        AST::Not.new(node.span, operand)
      end
    end

    def visit_if(node : AST::If) : AST::Expr
      cond = visit(node.cond)
      
      # If condition is constant, we can simplify
      if cond.is_a?(AST::BoolLit)
        if cond.value
          visit(node.then_expr)
        else
          visit(node.else_expr)
        end
      else
        then_expr = visit(node.then_expr)
        else_expr = visit(node.else_expr)
        AST::If.new(node.span, cond, then_expr, else_expr)
      end
    end
  end
end

# Example usage
def main
  # Create a dummy span for our examples
  source_map = Hecate::Core::SourceMap.new
  source_id = source_map.add_file("example.lang", "dummy content")
  dummy_span = Hecate::Core::Span.new(source_id, 0_u32, 0_u32)

  # Build some example ASTs manually
  examples = [
    # Simple arithmetic: 2 + 3 * 4
    DynamicASTExample::AST::Add.new(
      dummy_span,
      DynamicASTExample::AST::IntLit.new(dummy_span, 2),
      DynamicASTExample::AST::Mul.new(
        dummy_span,
        DynamicASTExample::AST::IntLit.new(dummy_span, 3),
        DynamicASTExample::AST::IntLit.new(dummy_span, 4)
      )
    ),

    # Boolean expression: true && !false
    DynamicASTExample::AST::And.new(
      dummy_span,
      DynamicASTExample::AST::BoolLit.new(dummy_span, true),
      DynamicASTExample::AST::Not.new(
        dummy_span,
        DynamicASTExample::AST::BoolLit.new(dummy_span, false)
      )
    ),

    # Let expression: let x = 10 in x + 5
    DynamicASTExample::AST::Let.new(
      dummy_span,
      "x",
      DynamicASTExample::AST::IntLit.new(dummy_span, 10),
      DynamicASTExample::AST::Add.new(
        dummy_span,
        DynamicASTExample::AST::Var.new(dummy_span, "x"),
        DynamicASTExample::AST::IntLit.new(dummy_span, 5)
      )
    ),

    # If expression: if 5 < 10 then "yes" else "no"
    DynamicASTExample::AST::If.new(
      dummy_span,
      DynamicASTExample::AST::Lt.new(
        dummy_span,
        DynamicASTExample::AST::IntLit.new(dummy_span, 5),
        DynamicASTExample::AST::IntLit.new(dummy_span, 10)
      ),
      DynamicASTExample::AST::StringLit.new(dummy_span, "yes"),
      DynamicASTExample::AST::StringLit.new(dummy_span, "no")
    ),
  ]

  puts "=== Dynamic AST Example ==="
  
  examples.each_with_index do |expr, i|
    puts "\n--- Example #{i + 1} ---"
    
    # Pretty print
    printer = DynamicASTExample::PrettyPrinter.new
    puts "Expression: #{printer.visit(expr)}"
    
    # Pattern matching
    puts "Node type: #{expr.node_type_symbol}"
    puts "Is binary op? #{expr.is_a?(DynamicASTExample::AST::Add) || expr.is_a?(DynamicASTExample::AST::Sub)}"
    
    # Type inference
    inferer = DynamicASTExample::TypeInferer.new
    inferred_type = inferer.visit(expr)
    puts "Inferred type: #{inferred_type}"
    
    # Constant folding
    folder = DynamicASTExample::ConstantFolder.new
    folded = folder.visit(expr)
    
    if folded != expr
      puts "After folding: #{printer.visit(folded)}"
    end
  end

  # Demonstrate exhaustive matching
  puts "\n=== Exhaustive Matching ==="
  all_types = Hecate::AST::Node.all_node_types
  puts "All node types: #{all_types}"

  # Check if visitor handles all types
  handled_types = [
    :int_lit, :float_lit, :bool_lit, :string_lit,
    :add, :sub, :mul, :div,
    :eq, :lt,
    :and, :or, :not,
    :var, :let, :if_
  ]
  
  missing = Hecate::AST::Node.missing_from_match(handled_types)
  if missing.empty?
    puts "✓ All node types handled"
  else
    puts "✗ Missing types: #{missing}"
  end

  # Pattern matching with case expression
  puts "\n=== Pattern Matching with Case ==="
  expr = examples.first
  
  description = case expr
  when DynamicASTExample::AST::IntLit
    "Integer literal: #{expr.value}"
  when DynamicASTExample::AST::Add
    "Addition expression"
  when DynamicASTExample::AST::Let
    "Let binding for variable '#{expr.name}'"
  else
    "Other expression"
  end
  
  puts description
end

main