# hecate-ast

AST node definitions and utilities for the Hecate language toolkit. Provides a macro-based DSL for defining AST nodes with automatic visitor pattern support.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  hecate-ast:
    github: hecatecr/hecate-ast
```

## Usage

```crystal
require "hecate-ast"
require "hecate-core"

# Define your AST nodes in a module
module MyAST
  include Hecate::AST

  # Define abstract base types
  abstract_node Expr
  abstract_node Stmt

  # Define concrete node types
  node Add < Expr, left : Expr, right : Expr
  node IntLit < Expr, value : Int32
  node VarDecl < Stmt, name : String, value : Expr?

  # Finalize the AST to generate visitors and type predicates
  finalize_ast Add, IntLit, VarDecl
end

# Create a span for source location tracking
span = Hecate::Core::Span.new(0_u32, 0, 10)

# Use the generated nodes
ast = MyAST::Add.new(
  span,
  MyAST::IntLit.new(span, 1),
  MyAST::IntLit.new(span, 2)
)

# Visitor pattern support
class Evaluator < MyAST::Visitor(Int32)
  def visit_add(node : MyAST::Add) : Int32
    visit(node.left) + visit(node.right)
  end

  def visit_int_lit(node : MyAST::IntLit) : Int32
    node.value
  end

  def visit_var_decl(node : MyAST::VarDecl) : Int32
    0 # Variables evaluate to 0 in this example
  end
end

result = Evaluator.new.visit(ast) # => 3
```

## Features

- **Macro-based DSL** - Define AST nodes with minimal boilerplate
- **Automatic Visitor Pattern** - Generated visitor infrastructure
- **Span Tracking** - Built-in source location tracking
- **Tree Traversal** - Pre-order, post-order, and level-order traversal
- **Pattern Matching** - Crystal pattern matching support
- **Builder DSL** - Optional fluent API for AST construction
- **Debugging Tools** - Pretty printing and serialization
- **Validation Framework** - Custom validation rules for nodes

## Contributing

1. Fork it (<https://github.com/hecatecr/hecate/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Chris Watson](https://github.com/watzon) - creator and maintainer