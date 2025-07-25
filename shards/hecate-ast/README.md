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

# Define your AST nodes
Hecate::AST.define do
  abstract Expr
  abstract Stmt

  node Add < Expr, left: Expr, right: Expr
  node IntLit < Expr, value: Int32
  node VarDecl < Stmt, name: String, value: Expr?
end

# Use the generated nodes
ast = Add.new(
  IntLit.new(1, span),
  IntLit.new(2, span),
  span
)

# Visitor pattern support
class Evaluator < Hecate::AST::Visitor(Int32)
  def visit_add(node : Add) : Int32
    visit(node.left) + visit(node.right)
  end

  def visit_int_lit(node : IntLit) : Int32
    node.value
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