require "../../spec_helper"
require "json"

# Test AST for pretty printer specs - define in the spec file directly
include Hecate::AST

abstract_node TestExpr
abstract_node TestStmt

node TestIntLit < TestExpr, value : Int32
node TestStringLit < TestExpr, value : String
node TestBoolLit < TestExpr, value : Bool
node TestIdentifier < TestExpr, name : String

node TestBinaryOp < TestExpr, left : TestExpr, right : TestExpr, operator : String
node TestUnaryOp < TestExpr, operand : TestExpr, operator : String

node TestVarDecl < TestStmt, name : String, value : TestExpr?
node TestBlock < TestStmt, statements : Array(TestStmt)
node TestIf < TestStmt, condition : TestExpr, then_stmt : TestStmt, else_stmt : TestStmt?

finalize_ast TestIntLit, TestStringLit, TestBoolLit, TestIdentifier, TestBinaryOp, TestUnaryOp,
             TestVarDecl, TestBlock, TestIf

# Helper method for creating spans
def make_span(start_byte = 0, end_byte = 10)
  Hecate::Core::Span.new(0_u32, start_byte, end_byte)
end

describe Hecate::AST::PrettyPrinter do
  describe "#print" do
    it "prints simple literals in compact form" do
      node = TestIntLit.new(make_span, 42)
      printer = Hecate::AST::PrettyPrinter.new
      
      result = printer.print(node)
      result.should eq "TestIntLit(value: 42)"
    end
    
    it "prints nested expressions with indentation" do
      # Create: 1 + 2
      expr = TestBinaryOp.new(
        make_span(0, 5),
        TestIntLit.new(make_span(0, 1), 1),
        TestIntLit.new(make_span(4, 5), 2),
        "+"
      )
      
      printer = Hecate::AST::PrettyPrinter.new(indent_size: 2)
      result = printer.print(expr)
      
      expected = <<-PRETTY
      TestBinaryOp(operator: "+") {
        TestIntLit(value: 1)
        TestIntLit(value: 2)
      }
      PRETTY
      
      result.should eq expected.strip
    end
    
    it "prints complex nested structures" do
      # Create: if (x < 5) { y = 10; }
      if_stmt = TestIf.new(
        make_span,
        TestBinaryOp.new(
          make_span,
          TestIdentifier.new(make_span, "x"),
          TestIntLit.new(make_span, 5),
          "<"
        ),
        TestBlock.new(
          make_span,
          [TestVarDecl.new(make_span, "y", TestIntLit.new(make_span, 10)).as(TestStmt)]
        ),
        nil
      )
      
      printer = Hecate::AST::PrettyPrinter.new(indent_size: 2)
      result = printer.print(if_stmt)
      
      expected = <<-PRETTY
      TestIf {
        TestBinaryOp(operator: "<") {
          TestIdentifier(name: "x")
          TestIntLit(value: 5)
        }
        TestBlock {
          TestVarDecl(name: "y") {
            TestIntLit(value: 10)
          }
        }
      }
      PRETTY
      
      result.should eq expected.strip
    end
    
    it "prints in compact mode when requested" do
      expr = TestBinaryOp.new(
        make_span,
        TestIntLit.new(make_span, 1),
        TestIntLit.new(make_span, 2),
        "+"
      )
      
      printer = Hecate::AST::PrettyPrinter.new(compact: true)
      result = printer.print(expr)
      
      result.should eq "TestBinaryOp(operator: \"+\"), TestIntLit(value: 1), TestIntLit(value: 2)"
    end
  end
end

describe Hecate::AST::SExpPrinter do
  describe "#print" do
    it "prints simple literals as S-expressions" do
      node = TestIntLit.new(make_span, 42)
      printer = Hecate::AST::SExpPrinter.new
      
      result = printer.print(node)
      result.should eq "(test_int_lit 42)"
    end
    
    it "prints strings with proper escaping" do
      node = TestStringLit.new(make_span, "hello \"world\"\n")
      printer = Hecate::AST::SExpPrinter.new
      
      result = printer.print(node)
      result.should eq "(test_string_lit \"hello \\\"world\\\"\\n\")"
    end
    
    it "prints boolean values in Lisp style" do
      true_node = TestBoolLit.new(make_span, true)
      false_node = TestBoolLit.new(make_span, false)
      printer = Hecate::AST::SExpPrinter.new
      
      printer.print(true_node).should eq "(test_bool_lit #t)"
      printer.print(false_node).should eq "(test_bool_lit #f)"
    end
    
    it "prints nested expressions" do
      # Create: 1 + 2 * 3
      expr = TestBinaryOp.new(
        make_span,
        TestIntLit.new(make_span, 1),
        TestBinaryOp.new(
          make_span,
          TestIntLit.new(make_span, 2),
          TestIntLit.new(make_span, 3),
          "*"
        ),
        "+"
      )
      
      printer = Hecate::AST::SExpPrinter.new
      result = printer.print(expr)
      
      result.should eq "(test_binary_op \"+\" (test_int_lit 1) (test_binary_op \"*\" (test_int_lit 2) (test_int_lit 3)))"
    end
  end
end

describe Hecate::AST::JSONSerializer do
  describe ".to_json" do
    it "serializes simple nodes to JSON" do
      node = TestIntLit.new(make_span(5, 7), 42)
      json_str = node.to_json
      
      json = JSON.parse(json_str)
      json["type"].should eq "TestIntLit"
      json["value"].should eq 42
      json["span"]["source_id"].should eq 0
      json["span"]["start_byte"].should eq 5
      json["span"]["end_byte"].should eq 7
    end
    
    it "serializes nested structures" do
      expr = TestBinaryOp.new(
        make_span(0, 5),
        TestIntLit.new(make_span(0, 1), 1),
        TestIntLit.new(make_span(4, 5), 2),
        "+"
      )
      
      json_str = expr.to_json
      json = JSON.parse(json_str)
      
      json["type"].should eq "TestBinaryOp"
      json["operator"].should eq "+"
      json["children"].as_a.size.should eq 2
      json["children"][0]["type"].should eq "TestIntLit"
      json["children"][0]["value"].should eq 1
      json["children"][1]["type"].should eq "TestIntLit"
      json["children"][1]["value"].should eq 2
    end
    
    it "handles nil values correctly" do
      node = TestVarDecl.new(make_span, "x", nil)
      json_str = node.to_json
      
      json = JSON.parse(json_str)
      json["type"].should eq "TestVarDecl"
      json["name"].should eq "x"
      json["children"]?.should be_nil  # No children since value is nil
    end
  end
end

describe Hecate::AST::TreePrinter do
  describe "#print" do
    it "prints a tree visualization" do
      # Create: if (x < 5) { y = 10; }
      if_stmt = TestIf.new(
        make_span,
        TestBinaryOp.new(
          make_span,
          TestIdentifier.new(make_span, "x"),
          TestIntLit.new(make_span, 5),
          "<"
        ),
        TestBlock.new(
          make_span,
          [TestVarDecl.new(make_span, "y", TestIntLit.new(make_span, 10)).as(TestStmt)]
        ),
        nil
      )
      
      io = IO::Memory.new
      printer = Hecate::AST::TreePrinter.new
      printer.print(if_stmt, io)
      
      result = io.to_s
      result.should contain "└── TestIf"
      result.should contain "├── TestBinaryOp"
      result.should contain "│   ├── TestIdentifier(\"x\")"
      result.should contain "│   └── TestIntLit(5)"
      result.should contain "└── TestBlock"
      result.should contain "    └── TestVarDecl(\"y\")"
      result.should contain "        └── TestIntLit(10)"
    end
  end
end

describe "Node extension methods" do
  it "provides convenience methods on nodes" do
    node = TestIntLit.new(make_span, 42)
    
    # Test pretty_print
    node.pretty_print.should eq "TestIntLit(value: 42)"
    
    # Test to_sexp
    node.to_sexp.should eq "(test_int_lit 42)"
    
    # Test to_compact_s
    node.to_compact_s.should eq "TestIntLit(value: 42)"
    
    # Test to_json
    json = JSON.parse(node.to_json)
    json["type"].should eq "TestIntLit"
    json["value"].should eq 42
  end
  
  it "provides source snippet extraction" do
    source = <<-SRC
    x = 42
    y = x + 10
    print(y)
    SRC
    
    # Node for "42" on line 1 (bytes 4-6)
    node = TestIntLit.new(Hecate::Core::Span.new(0_u32, 4, 6), 42)
    
    snippet = node.source_snippet(source, context_lines: 1)
    snippet.should_not be_nil
    snippet.not_nil!.should contain "1:   │ x = 42"
    snippet.not_nil!.should contain "2:     y = x + 10"
  end
end