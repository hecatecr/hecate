# hecate-ast

AST node definitions and utilities for the Hecate language toolkit.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [Basic Usage](#basic-usage)
  - [Visitor Pattern](#visitor-pattern)
  - [Builder DSL](#builder-dsl)
  - [Validation](#validation)
- [API](#api)
  - [Node Definition](#node-definition)
  - [Tree Traversal](#tree-traversal)
  - [Pattern Matching](#pattern-matching)
- [Contributing](#contributing)
- [License](#license)

## Install

Add this to your application's `shard.yml`:

```yaml
dependencies:
  hecate-ast:
    github: hecatecr/hecate-ast
    version: ~> 0.1.0
```

Then run `shards install`

## Usage

### Basic Usage

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
```

### Visitor Pattern

Implement visitors to process AST nodes:

```crystal
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

### Builder DSL

Use the fluent builder API for AST construction:

```crystal
module MyAST
  include Hecate::AST
  
  # Define your nodes first
  abstract_node Expr
  node Add < Expr, left : Expr, right : Expr
  node IntLit < Expr, value : Int32
  
  finalize_ast Add, IntLit
  
  # Extend Builder with methods for your nodes
  module Builder
    extend self
    
    DEFAULT_SPAN = ::Hecate::Core::Span.new(0_u32, 0, 0)
    
    def int_lit(value : Int32, span = DEFAULT_SPAN)
      IntLit.new(span, value)
    end
    
    def add(left : Expr, right : Expr, span = DEFAULT_SPAN)
      Add.new(span, left, right)
    end
    
    def build(&block)
      with self yield
    end
  end
end

# Build AST using DSL
ast = MyAST::Builder.build do
  add(int_lit(1), int_lit(2))
end
```

### Validation

Add validation rules to your AST nodes:

```crystal
module MyAST
  node VarDecl < Stmt, name : String, value : Expr? do
    validate do
      if name.empty?
        error "Variable name cannot be empty"
      end
      
      if name !~ /^[a-zA-Z_]\w*$/
        error "Invalid variable name: #{name}"
      end
    end
  end
end

# Validate nodes
validator = Hecate::AST::ASTValidator.new
validator.visit(ast)

if validator.valid?
  puts "AST is valid!"
else
  validator.errors.each do |error|
    puts "Validation error: #{error.message}"
  end
end
```

## API

### Node Definition

Define AST nodes using the macro DSL:

```crystal
# Abstract nodes (cannot be instantiated)
abstract_node BaseType

# Concrete nodes with fields
node NodeName < ParentType, field1 : Type1, field2 : Type2?

# Nodes with validation
node ValidatedNode < BaseType, value : String do
  validate do
    error "message" if condition
  end
end

# Finalize to generate visitor infrastructure
finalize_ast Node1, Node2, Node3
```

### Tree Traversal

Built-in traversal methods:

```crystal
# Pre-order traversal
Hecate::AST::TreeWalk.preorder(ast) do |node|
  puts node.class.name
end

# Post-order traversal
Hecate::AST::TreeWalk.postorder(ast) do |node|
  process(node)
end

# Level-order traversal (breadth-first)
Hecate::AST::TreeWalk.level_order(ast) do |node|
  puts node
end

# Depth-aware traversal
Hecate::AST::TreeWalk.with_depth(ast) do |node, depth|
  puts "#{"  " * depth}#{node}"
end

# Find specific nodes
Hecate::AST::TreeWalk.find_all(ast, MyAST::IntLit) # => Array of all IntLit nodes
```

### Pattern Matching

Use Crystal's pattern matching with AST nodes:

```crystal
case node
when MyAST::Add
  "Addition of #{node.left} and #{node.right}"
when MyAST::IntLit
  "Integer literal: #{node.value}"
when MyAST::VarDecl
  "Variable #{node.name}"
else
  "Unknown node"
end
```

For complete API documentation, see the [Crystal docs](https://hecatecr.github.io/hecate-ast).

## Contributing

This repository is a read-only mirror. All development happens in the [Hecate monorepo](https://github.com/hecatecr/hecate).

- **Issues**: Please file issues in the [main repository](https://github.com/hecatecr/hecate/issues)
- **Pull Requests**: Submit PRs to the [monorepo](https://github.com/hecatecr/hecate)
- **Questions**: Open a discussion in the [monorepo discussions](https://github.com/hecatecr/hecate/discussions)

## License

MIT © Chris Watson. See [LICENSE](LICENSE) for details.