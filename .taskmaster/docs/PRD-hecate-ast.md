# Hecate AST – Product Requirements Document

**Component:** `hecate-ast`  
**Author:** watzon  
**Status:** Draft v1  
**Last Updated:** 2025-07-25

---

## 1. Executive Summary

The `hecate-ast` shard provides a powerful, macro-based DSL for defining Abstract Syntax Tree (AST) nodes in Crystal. It automatically generates visitor patterns, pattern matching support, tree traversal utilities, and transformation capabilities. This component serves as the foundation for representing parsed code structure in languages built with Hecate.

### Key Value Propositions
- **Zero Boilerplate**: Define AST nodes with minimal syntax, get full functionality
- **Type Safety**: Leverages Crystal's type system for compile-time guarantees
- **Ergonomic API**: Natural syntax for tree operations and transformations
- **Performance**: Minimal runtime overhead through compile-time code generation
- **Integration**: Seamless integration with parser and semantic analysis phases

---

## 2. Problem Statement

Building a new programming language requires defining numerous AST node types with common functionality:
- Visitor pattern implementation for tree traversal
- Pattern matching for node type discrimination
- Span tracking for error reporting
- Tree utilities (cloning, equality, traversal)
- Transformation support for optimization passes

Writing this boilerplate manually is:
- **Time-consuming**: Hundreds of lines per node type
- **Error-prone**: Easy to miss implementing required methods
- **Inconsistent**: Different developers implement differently
- **Maintenance burden**: Changes require updating multiple places

---

## 3. Goals

### Primary Goals
1. **Declarative AST Definition**: Simple DSL for defining node structure
2. **Automatic Code Generation**: Generate all boilerplate at compile-time
3. **Type-Safe Operations**: Leverage Crystal's type system fully
4. **Zero Runtime Overhead**: All generation happens at compile-time
5. **Span Integration**: Every node automatically tracks source location

### Secondary Goals
1. **Extensibility**: Users can add custom methods to generated nodes
2. **Debugging Support**: Pretty-printing and inspection utilities
3. **Documentation**: Generate documentation from DSL definitions
4. **Performance**: Efficient tree operations for large ASTs
5. **Compatibility**: Work seamlessly with other Hecate components

---

## 4. Non-Goals

1. **Runtime AST Modification**: Not a dynamic AST builder
2. **Serialization Format**: Not a persistence layer (separate concern)
3. **Language-Specific Nodes**: Provides framework, not concrete language ASTs
4. **Semantic Information**: AST is purely syntactic; semantics in separate phase
5. **Code Generation**: Not responsible for target code emission

---

## 5. User Stories

### Language Designer
> "As a language designer, I want to define my AST structure declaratively so I can focus on language design rather than boilerplate implementation."

### Parser Developer
> "As a parser developer, I want to easily create AST nodes during parsing with automatic span tracking so error messages have accurate locations."

### Compiler Developer
> "As a compiler developer, I want type-safe visitor patterns so I can implement multiple analysis and transformation passes without runtime type checks."

### Tool Developer
> "As a tool developer, I want tree traversal utilities so I can implement formatters, linters, and refactoring tools efficiently."

### Performance Engineer
> "As a performance engineer, I want minimal overhead AST operations so my compiler can handle large codebases efficiently."

---

## 6. Core Features

### 6.1 AST Definition DSL

```crystal
module MyLang
  Hecate::AST.define do
    # Abstract base types
    abstract Expr
    abstract Stmt
    abstract Type
    
    # Expression nodes
    node IntLit < Expr, value: Int32
    node StringLit < Expr, value: String
    node Identifier < Expr, name: String
    
    # Binary operations
    node Add < Expr, left: Expr, right: Expr
    node Mul < Expr, left: Expr, right: Expr
    
    # Control flow
    node If < Expr, 
      condition: Expr, 
      then_branch: Expr, 
      else_branch: Expr?
      
    # Statements
    node VarDecl < Stmt,
      name: String,
      type: Type?,
      init: Expr?
      
    # Collections
    node Block < Stmt,
      statements: Array(Stmt)
  end
end
```

### 6.2 Generated Visitor Pattern

```crystal
# Automatically generated
abstract class Visitor(T)
  abstract def visit_int_lit(node : IntLit) : T
  abstract def visit_add(node : Add) : T
  abstract def visit_if(node : If) : T
  # ... for all nodes
  
  def visit(node : Node) : T
    node.accept(self)
  end
end

# User implementation
class Evaluator < Visitor(Int32)
  def visit_int_lit(node : IntLit) : Int32
    node.value
  end
  
  def visit_add(node : Add) : Int32
    visit(node.left) + visit(node.right)
  end
end
```

### 6.3 Pattern Matching Support

```crystal
def evaluate(expr : Expr) : Int32
  case expr
  when IntLit
    expr.value
  when Add
    evaluate(expr.left) + evaluate(expr.right)
  when Mul
    evaluate(expr.left) * evaluate(expr.right)
  else
    raise "Unknown expression: #{expr.class}"
  end
end
```

### 6.4 Tree Traversal Utilities

```crystal
# Find all identifiers in the tree
identifiers = TreeWalk.find_all(ast, Identifier)

# Pre-order traversal
TreeWalk.preorder(ast) do |node|
  puts "Visiting: #{node.class}"
end

# Post-order traversal
TreeWalk.postorder(ast) do |node|
  # Process after children
end

# Parent tracking
walker = ParentTracker.new(ast)
parent = walker.parent_of(some_node)

# Depth tracking
TreeWalk.with_depth(ast) do |node, depth|
  puts "#{"  " * depth}#{node.class}"
end
```

### 6.5 Tree Transformation

```crystal
# Base transformer
abstract class Transformer < Visitor(Node)
  # Default: return node unchanged
  {% for node in all_node_types %}
    def visit_{{node.downcase}}(node : {{node}}) : Node
      # Transform children if any
      # Return new node if changed
    end
  {% end %}
end

# Constant folding example
class ConstantFolder < Transformer
  def visit_add(node : Add) : Node
    left = visit(node.left).as(Expr)
    right = visit(node.right).as(Expr)
    
    if left.is_a?(IntLit) && right.is_a?(IntLit)
      IntLit.new(left.value + right.value, node.span)
    else
      Add.new(left, right, node.span)
    end
  end
end

# Apply transformation
optimizer = ConstantFolder.new
optimized_ast = optimizer.visit(ast)
```

### 6.6 Builder Pattern Support

```crystal
# Optionally generate builders
Hecate::AST.define do
  # ... node definitions ...
  
  generate_builders true
end

# Usage
ast = MyLang::Builder.build do
  function("main") do
    var("x", Int32, int(10))
    var("y", Int32, int(20))
    return(add(ref("x"), ref("y")))
  end
end
```

### 6.7 Debugging and Pretty Printing

```crystal
# Automatic to_s for debugging
puts ast.to_s
# => "Add(IntLit(10), IntLit(20))"

# Pretty printer
printer = PrettyPrinter.new
puts printer.print(ast)
# => "10 + 20"

# S-expression format
puts ast.to_sexp
# => "(add (int 10) (int 20))"

# JSON representation
puts ast.to_json
# => {"type": "Add", "left": {...}, "right": {...}}
```

### 6.8 Validation Support

```crystal
# Node validation
Hecate::AST.define do
  node Div < Expr, left: Expr, right: Expr do
    validate do |node|
      if node.right.is_a?(IntLit) && node.right.value == 0
        Error.new("Division by zero", node.right.span)
      end
    end
  end
end

# Structural validation
validator = ASTValidator.new
errors = validator.validate(ast)
```

---

## 7. Technical Architecture

### 7.1 Module Structure

```
src/hecate/ast/
  dsl.cr              # Main DSL implementation
  node.cr             # Base Node class
  visitor.cr          # Visitor pattern base
  transformer.cr      # Transformation base
  builder.cr          # Builder pattern support
  traversal.cr        # Tree walking utilities
  pretty_printer.cr   # Pretty printing
  validator.cr        # Validation framework
  macros/
    node_generator.cr    # Node class generation
    visitor_generator.cr # Visitor generation
    builder_generator.cr # Builder generation
```

### 7.2 Code Generation Pipeline

```crystal
# 1. DSL captures node definitions
AST.define do
  node Add < Expr, left: Expr, right: Expr
end

# 2. Macro processes definition
macro node(definition)
  # Parse node name, parent, fields
  # Generate class with:
  # - Field getters
  # - Constructor
  # - Visitor accept method
  # - Pattern matching support
  # - Equality/clone/to_s
  # - Children extraction
end

# 3. Visitor interface generation
macro finalize_ast
  # Generate abstract Visitor class
  # with visit_* methods for all nodes
end
```

### 7.3 Integration Points

```crystal
# Parser integration
rule :expr do
  left ~ plus ~ right >> do |l, _, r|
    MyLang::Add.new(l, r, span_from(l, r))
  end
end

# Semantic analysis integration
class TypeChecker < Visitor(Type)
  def visit_add(node : Add) : Type
    left_type = visit(node.left)
    right_type = visit(node.right)
    unify(left_type, right_type, node.span)
  end
end

# IR generation integration
class IRBuilder < Visitor(IR::Value)
  def visit_add(node : Add) : IR::Value
    left = visit(node.left)
    right = visit(node.right)
    @builder.add(left, right)
  end
end
```

---

## 8. API Reference

### 8.1 DSL Commands

```crystal
# Define abstract base type
abstract TypeName

# Define concrete node
node NodeName < ParentType, field: Type, field2: Type

# Node with validation
node NodeName < ParentType, field: Type do
  validate do |node|
    # Return Error or nil
  end
end

# Enable builder generation
generate_builders true

# Enable serialization support
generate_serialization :json, :msgpack

# Custom node methods
node NodeName < ParentType, field: Type do
  def custom_method
    # Implementation
  end
end
```

### 8.2 Generated Node API

```crystal
class NodeName < ParentType
  # Field accessors
  getter field : Type
  getter span : Hecate::Span
  
  # Constructor
  def initialize(@field : Type, @span : Hecate::Span)
  
  # Visitor pattern
  def accept(visitor)
  
  # Tree traversal
  def children : Array(Node)
  
  # Utilities
  def ==(other : NodeName) : Bool
  def clone : NodeName
  def to_s(io : IO) : Nil
  
  # Pattern matching
  def is_a?(type : T.class) : Bool forall T
end
```

### 8.3 Visitor API

```crystal
abstract class Visitor(T)
  # Visit methods for each node type
  abstract def visit_node_name(node : NodeName) : T
  
  # Generic visit
  def visit(node : Node) : T
end
```

### 8.4 Tree Utilities API

```crystal
module TreeWalk
  # Traversal methods
  def self.preorder(node : Node, &block : Node ->)
  def self.postorder(node : Node, &block : Node ->)
  def self.level_order(node : Node, &block : Node ->)
  
  # Search methods
  def self.find_all(node : Node, type : T.class) : Array(T)
  def self.find_first(node : Node, type : T.class) : T?
  def self.find_parent(node : Node, child : Node) : Node?
  
  # Analysis methods
  def self.depth(node : Node) : Int32
  def self.node_count(node : Node) : Int32
  def self.leaf_count(node : Node) : Int32
end
```

---

## 9. Usage Examples

### 9.1 Basic Language AST

```crystal
module TinyLang
  Hecate::AST.define do
    # Base types
    abstract Node
    abstract Expr < Node
    abstract Stmt < Node
    
    # Literals
    node IntLit < Expr, value: Int32
    node BoolLit < Expr, value: Bool
    node StringLit < Expr, value: String
    
    # Variables
    node Var < Expr, name: String
    node Assign < Expr, target: String, value: Expr
    
    # Operations
    node BinOp < Expr, op: String, left: Expr, right: Expr
    node UnOp < Expr, op: String, operand: Expr
    
    # Control flow
    node If < Stmt, cond: Expr, then: Stmt, else: Stmt?
    node While < Stmt, cond: Expr, body: Stmt
    node Block < Stmt, stmts: Array(Stmt)
    
    # Functions
    node FunDef < Stmt, 
      name: String, 
      params: Array(String), 
      body: Stmt
    node Call < Expr, 
      name: String, 
      args: Array(Expr)
  end
end
```

### 9.2 Type Checker Implementation

```crystal
class TypeChecker < TinyLang::Visitor(Type)
  def initialize
    @env = TypeEnvironment.new
  end
  
  def visit_int_lit(node : IntLit) : Type
    Type::Int.new
  end
  
  def visit_var(node : Var) : Type
    @env.lookup(node.name) || error("Undefined variable", node.span)
  end
  
  def visit_bin_op(node : BinOp) : Type
    left = visit(node.left)
    right = visit(node.right)
    
    case node.op
    when "+", "-", "*", "/"
      require_numeric(left, node.left.span)
      require_numeric(right, node.right.span)
      Type::Int.new
    when "==", "!="
      unify(left, right, node.span)
      Type::Bool.new
    else
      error("Unknown operator: #{node.op}", node.span)
    end
  end
end
```

### 9.3 Interpreter Implementation

```crystal
class Interpreter < TinyLang::Visitor(Value)
  def initialize
    @env = Environment.new
  end
  
  def visit_int_lit(node : IntLit) : Value
    Value::Int.new(node.value)
  end
  
  def visit_bin_op(node : BinOp) : Value
    left = visit(node.left)
    right = visit(node.right)
    
    case node.op
    when "+"
      Value::Int.new(left.as_int + right.as_int)
    when "-"
      Value::Int.new(left.as_int - right.as_int)
    # ... more operations
    end
  end
  
  def visit_if(node : If) : Value
    cond = visit(node.cond)
    if cond.as_bool
      visit(node.then)
    elsif node.else
      visit(node.else.not_nil!)
    else
      Value::Nil.new
    end
  end
end
```

### 9.4 AST Optimizer

```crystal
class Optimizer < TinyLang::Transformer
  def visit_bin_op(node : BinOp) : Node
    left = visit(node.left).as(Expr)
    right = visit(node.right).as(Expr)
    
    # Constant folding
    if left.is_a?(IntLit) && right.is_a?(IntLit)
      case node.op
      when "+"
        IntLit.new(left.value + right.value, node.span)
      when "*"
        IntLit.new(left.value * right.value, node.span)
      else
        BinOp.new(node.op, left, right, node.span)
      end
    # Algebraic simplification
    elsif node.op == "+" && right.is_a?(IntLit) && right.value == 0
      left
    elsif node.op == "*" && right.is_a?(IntLit) && right.value == 1
      left
    else
      BinOp.new(node.op, left, right, node.span)
    end
  end
end
```

---

## 10. Performance Considerations

### 10.1 Compile-Time Performance
- Macro expansion is linear in number of nodes
- Generated code is optimized by Crystal compiler
- No runtime reflection or metaprogramming

### 10.2 Runtime Performance
- Direct method dispatch (no virtual tables)
- Visitor pattern uses single dynamic dispatch
- Minimal memory overhead per node
- Efficient tree traversal algorithms

### 10.3 Memory Efficiency
- Nodes are immutable after creation
- Shared structure for common subtrees
- Efficient span representation
- No unnecessary boxing/unboxing

---

## 11. Testing Strategy

### 11.1 Unit Tests
- DSL parsing and validation
- Code generation correctness
- Visitor pattern behavior
- Tree utility algorithms
- Edge cases and error handling

### 11.2 Integration Tests
- Parser integration
- Complex AST construction
- Multi-pass transformations
- Performance benchmarks

### 11.3 Golden File Tests
- Generated code snapshots
- AST structure verification
- Pretty printer output
- Serialization formats

### 11.4 Property-Based Tests
- Tree invariants
- Visitor completeness
- Transformation properties
- Traversal correctness

---

## 12. Migration Path

### 12.1 From Manual AST
```crystal
# Before: Manual implementation
class Add
  getter left : Expr
  getter right : Expr
  getter span : Span
  
  def initialize(@left, @right, @span)
  end
  
  def accept(visitor)
    visitor.visit_add(self)
  end
  
  # ... more boilerplate
end

# After: DSL
Hecate::AST.define do
  node Add < Expr, left: Expr, right: Expr
end
```

### 12.2 Incremental Adoption
1. Define new nodes with DSL
2. Gradually migrate existing nodes
3. Update visitors incrementally
4. Remove manual boilerplate

---

## 13. Success Metrics

### 13.1 Developer Productivity
- **Lines of Code**: 80% reduction in AST definition
- **Time to Feature**: 5x faster AST changes
- **Bug Rate**: 90% fewer AST-related bugs

### 13.2 Performance Metrics
- **Compile Time**: < 100ms for 100 node types
- **Runtime Overhead**: < 5% vs manual implementation
- **Memory Usage**: Equal or better than manual

### 13.3 Adoption Metrics
- **User Satisfaction**: > 90% prefer DSL
- **Documentation Coverage**: 100% API docs
- **Example Coverage**: 10+ working examples

---

## 14. Risk Analysis

### 14.1 Technical Risks
- **Macro Complexity**: Mitigate with thorough testing
- **Error Messages**: Provide clear DSL error reporting
- **Breaking Changes**: Semantic versioning from start

### 14.2 Adoption Risks
- **Learning Curve**: Comprehensive documentation
- **Migration Effort**: Clear migration guide
- **Performance Concerns**: Publish benchmarks

---

## 15. Future Enhancements

### 15.1 Version 1.1
- Custom visitor generation strategies
- Attribute grammars support
- Incremental tree updates

### 15.2 Version 1.2
- Language-specific node libraries
- Visual AST explorer
- AST diffing utilities

### 15.3 Version 2.0
- Type-parameterized nodes
- Higher-order tree operations
- Query language for AST

---

## 16. Dependencies

### 16.1 Required Dependencies
- `hecate-core`: For diagnostics and spans

### 16.2 Development Dependencies
- Crystal spec framework
- Benchmark utilities

### 16.3 Optional Dependencies
- JSON serialization
- MessagePack support

---

## 17. Deliverables

### 17.1 Phase 1 (MVP)
- [ ] Core DSL implementation
- [ ] Basic node generation
- [ ] Visitor pattern support
- [ ] README and examples

### 17.2 Phase 2
- [ ] Tree utilities
- [ ] Transformer base
- [ ] Pattern matching
- [ ] API documentation

### 17.3 Phase 3
- [ ] Builder pattern
- [ ] Validation framework
- [ ] Pretty printing
- [ ] Performance optimizations

### 17.4 Phase 4
- [ ] Advanced features
- [ ] Integration guides
- [ ] Migration tools
- [ ] 1.0 release

---

## 18. Documentation Requirements

### 18.1 API Documentation
- All public methods documented
- Usage examples for each feature
- Common patterns guide

### 18.2 Tutorials
- "Your First AST in 10 Minutes"
- "Implementing a Tree Walker"
- "AST Transformations Guide"

### 18.3 Reference
- Complete DSL command reference
- Generated method reference
- Performance tuning guide

---

## 19. Conclusion

The `hecate-ast` shard will provide a powerful, ergonomic way to define AST structures for new languages. By leveraging Crystal's macro system, we can eliminate boilerplate while maintaining type safety and performance. This component is essential for making Hecate a productive toolkit for language development.