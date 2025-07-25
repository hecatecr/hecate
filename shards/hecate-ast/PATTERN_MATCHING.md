# Pattern Matching and Type Discrimination

The Hecate AST framework provides comprehensive pattern matching and type discrimination features that make it easy to work with AST nodes in a type-safe manner.

## Features Overview

1. **Type Predicate Methods** - Generated methods like `int_lit?`, `binary_op?` for type checking
2. **Crystal case/when Support** - Seamless integration with Crystal's pattern matching
3. **Type Discrimination Helpers** - Methods to categorize nodes (expressions vs statements)
4. **Exhaustive Pattern Matching** - Tools to validate that all node types are handled
5. **Symbol-based Matching** - Use symbols for dynamic pattern matching scenarios

## Type Predicate Methods

For each node type you define, the framework automatically generates predicate methods:

```crystal
# Define your AST
module MyAST
  include Hecate::AST
  
  abstract_node Expr
  node IntLit < Expr, value : Int32
  node BinaryOp < Expr, left : Expr, right : Expr, operator : String
  
  finalize_ast IntLit, BinaryOp
end

# Use predicate methods
node = MyAST::IntLit.new(span, 42)
node.int_lit?     # => true
node.binary_op?   # => false
```

### Generated Methods

For each node type `NodeName`, these methods are generated:

- `node_name?` on the specific node class (returns `true`)
- `node_name?` on the base `Node` class (returns `false` by default)
- `node_type_symbol` returns the node type as a symbol (`:node_name`)
- `expression?` returns `true` if the node appears to be an expression
- `statement?` returns `true` if the node appears to be a statement

## Crystal case/when Pattern Matching

The framework works seamlessly with Crystal's native case/when pattern matching:

```crystal
result = case node
         when MyAST::IntLit
           "Integer: #{node.value}"
         when MyAST::BinaryOp
           "Binary operation: #{node.operator}"
         else
           "Unknown node type"
         end
```

### Nested Pattern Matching

You can also pattern match on nested structures:

```crystal
case binary_op
when MyAST::BinaryOp
  left_value = case binary_op.left
               when MyAST::IntLit
                 binary_op.left.as(MyAST::IntLit).value
               else
                 0
               end
  puts "Left operand: #{left_value}"
end
```

### Pattern Matching with Guards

Combine type matching with conditional logic:

```crystal
result = case node
         when MyAST::IntLit
           if node.value < 0
             "Negative"
           elsif node.value == 0
             "Zero"
           else
             "Positive"
           end
         when MyAST::BinaryOp
           case node.operator
           when "+", "-"
             "Arithmetic"
           when "==", "!="
             "Comparison"
           else
             "Other operation"
           end
         end
```

## Abstract Type Matching

Match against abstract base types to handle groups of related nodes:

```crystal
category = case node
           when MyAST::Expr
             "Expression"
           when MyAST::Stmt
             "Statement"
           else
             "Unknown"
           end
```

## Type Discrimination Helpers

Use built-in helper methods for common categorizations:

```crystal
# Separate expressions from statements
expressions = nodes.select(&.expression?)
statements = nodes.select(&.statement?)

# Get type information
node.node_type_symbol  # => :int_lit, :binary_op, etc.
```

## Exhaustive Pattern Matching

The framework provides tools to ensure your pattern matches handle all possible node types:

### Check Coverage

```crystal
# Get all possible node types
all_types = Hecate::AST::Node.all_node_types
# => [:int_lit, :binary_op, :var_decl, ...]

# Check if a pattern is exhaustive
handled_types = [:int_lit, :binary_op]
is_complete = Hecate::AST::Node.exhaustive_match?(handled_types)
# => false

# Find missing types
missing = Hecate::AST::Node.missing_from_match(handled_types)
# => [:var_decl, :block, ...]
```

### Validate Exhaustiveness

```crystal
# This will raise an exception if the pattern is incomplete
Hecate::AST::Node.validate_exhaustive_match([:int_lit, :binary_op])
# => Exception: "Non-exhaustive pattern match. Missing cases for: var_decl, block"

# This will succeed
complete_pattern = [:int_lit, :binary_op, :var_decl, :block]
Hecate::AST::Node.validate_exhaustive_match(complete_pattern)
# => (no exception)
```

### Development Workflow

Use exhaustive matching during development to catch incomplete patterns:

```crystal
def process_node(node)
  # Validate that we handle all types (useful during development)
  handled_types = [:int_lit, :binary_op, :var_decl]
  begin
    Hecate::AST::Node.validate_exhaustive_match(handled_types)
  rescue ex
    puts "Warning: #{ex.message}"
  end
  
  case node
  when MyAST::IntLit
    # ...
  when MyAST::BinaryOp
    # ...
  when MyAST::VarDecl
    # ...
  # If you add new node types, the validation will catch missing cases
  end
end
```

## Symbol-based Pattern Matching

For dynamic scenarios, you can use symbols instead of direct type matching:

```crystal
result = case node.node_type_symbol
         when :int_lit
           "Integer literal"
         when :binary_op
           "Binary operation"
         when :var_decl
           "Variable declaration"
         else
           "Other type: #{node.node_type_symbol}"
         end
```

This is particularly useful when:
- Building generic tools that work with any AST
- Implementing serialization/deserialization
- Creating debugging or introspection tools

## Best Practices

### 1. Use Type-Specific Pattern Matching

Prefer specific type matching over generic approaches:

```crystal
# Good
case node
when MyAST::IntLit
  process_integer(node.value)
when MyAST::BinaryOp
  process_binary_op(node.operator, node.left, node.right)
end

# Less ideal
if node.int_lit?
  process_integer(node.as(MyAST::IntLit).value)
elsif node.binary_op?
  binary = node.as(MyAST::BinaryOp)
  process_binary_op(binary.operator, binary.left, binary.right)
end
```

### 2. Validate Exhaustiveness in Tests

Add tests to ensure your pattern matching is complete:

```crystal
it "handles all node types" do
  # Test that your pattern matching covers all types
  all_types = Hecate::AST::Node.all_node_types
  handled_types = get_handled_types_from_your_code()
  
  Hecate::AST::Node.exhaustive_match?(handled_types).should be_true
end
```

### 3. Use Abstract Types for Common Operations

When you need to handle all expressions or all statements the same way:

```crystal
case node
when MyAST::Expr
  evaluate_expression(node)
when MyAST::Stmt
  execute_statement(node)
end
```

### 4. Combine Approaches

Mix different pattern matching techniques as needed:

```crystal
# First categorize broadly
case node
when MyAST::Expr
  # Then match specific expression types
  if node.int_lit?
    handle_integer(node.as(MyAST::IntLit))
  elsif node.binary_op?
    handle_binary_op(node.as(MyAST::BinaryOp))
  end
when MyAST::Stmt
  # Handle statements differently
  process_statement(node)
end
```

## Complete Example

See `examples/pattern_matching.cr` for a comprehensive example that demonstrates all these features in action.

## Integration with Visitors

Pattern matching works seamlessly with the visitor pattern:

```crystal
class MyVisitor < MyAST::Visitor(String)
  def visit_int_lit(node : MyAST::IntLit) : String
    # Type-safe - Crystal knows node is IntLit
    "int: #{node.value}"
  end
  
  def visit_binary_op(node : MyAST::BinaryOp) : String
    left = visit(node.left)
    right = visit(node.right)
    "#{left} #{node.operator} #{right}"
  end
end
```

The visitor pattern is great for recursive tree traversal, while pattern matching excels at handling individual nodes and implementing complex logic based on node types.