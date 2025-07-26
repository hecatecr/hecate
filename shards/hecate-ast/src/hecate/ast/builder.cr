require "./node"

module Hecate::AST
  # Builder pattern DSL for ergonomic AST construction
  #
  # This module provides a fluent API for building AST structures without
  # requiring manual span tracking. It's particularly useful in tests and
  # examples where the exact source positions are less important.
  #
  # The Builder module is designed to be extended by specific AST definitions.
  # When you define your AST nodes and call finalize_ast, you can then
  # manually add builder methods or use the generate_builders macro.
  #
  # Example usage pattern:
  #   module MyAST
  #     include Hecate::AST
  #
  #     abstract_node Expr
  #     node IntLit < Expr, value : Int32
  #     node Add < Expr, left : Expr, right : Expr
  #
  #     finalize_ast IntLit, Add
  #
  #     # Extend Builder with methods for your nodes
  #     module Builder
  #       extend self
  #
  #       DEFAULT_SPAN = ::Hecate::Core::Span.new(0_u32, 0, 0)
  #
  #       def int_lit(value : Int32, span = DEFAULT_SPAN)
  #         IntLit.new(span, value)
  #       end
  #
  #       def add(left : Expr, right : Expr, span = DEFAULT_SPAN)
  #         Add.new(span, left, right)
  #       end
  #
  #       def build(&block)
  #         with self yield
  #       end
  #     end
  #   end
  #
  #   # Usage:
  #   ast = MyAST::Builder.build do
  #     add(int_lit(1), int_lit(2))
  #   end
  module Builder
    extend self

    # This is a base module that provides common utilities.
    # Specific AST definitions should create their own Builder modules
    # that extend from this or implement similar patterns.

    # Default span for builder-constructed nodes
    # Uses zero-position span since builder is typically used in tests
    # where exact source positions are not critical
    DEFAULT_SPAN = ::Hecate::Core::Span.new(0_u32, 0, 0)

    # Block-based DSL construction helper
    # This method can be included in specific builder implementations
    # to enable block-based syntax
    def build(&block)
      with self yield
    end
  end
end
