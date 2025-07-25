require "../src/hecate-core"

# Create a source map and add sample files
source_map = Hecate::Core::SourceMap.new

# Example with complex overlapping scenarios
complex_code = %q{class Calculator
  def initialize(@precision : Int32 = 2)
    @history = [] of String
  end

  def calculate(expression)
    result = parse_and_evaluate(expression)
    @history << "#{expression} = #{result}"
    format_result(result)
  end

  private def parse_and_evaluate(expr)
    # This method has multiple responsibilities
    tokens = tokenize(expr)
    ast = parse_tokens(tokens)
    evaluate_ast(ast)
  end
end}

source_id = source_map.add_file("calculator.cr", complex_code)
renderer = Hecate::Core::TTYRenderer.new(STDOUT, 100)

puts "=== Enhanced TTY Renderer Demo ==="
puts

# Example 1: Overlapping labels on same line
puts "1. Overlapping Labels:"

# Find the actual positions we want to highlight
precision_param_pos = complex_code.index("@precision").not_nil!
precision_param_end = precision_param_pos + "@precision".size

default_value_pos = complex_code.index("= 2").not_nil!
default_value_end = default_value_pos + "= 2".size

span1 = Hecate::Core::Span.new(source_id, precision_param_pos, precision_param_end) # "@precision"
span2 = Hecate::Core::Span.new(source_id, default_value_pos, default_value_end)     # "= 2"

diagnostic1 = Hecate::Core::Diagnostic.new(
  Hecate::Core::Diagnostic::Severity::Warning,
  "parameter naming issues"
)
diagnostic1.primary(span1, "parameter name could be shorter")
diagnostic1.secondary(span2, "default value might be unclear")
diagnostic1.help("consider using simpler names and explicit documentation")

renderer.emit(diagnostic1, source_map)
puts

# Example 2: Multi-line method analysis with specific line highlights
puts "2. Multi-line Method Analysis:"

# Highlight specific problematic lines
tokenize_line_pos = complex_code.index("tokens = tokenize(expr)").not_nil!
tokenize_line_end = tokenize_line_pos + "tokens = tokenize(expr)".size

parse_line_pos = complex_code.index("ast = parse_tokens(tokens)").not_nil!
parse_line_end = parse_line_pos + "ast = parse_tokens(tokens)".size

evaluate_line_pos = complex_code.index("evaluate_ast(ast)").not_nil!
evaluate_line_end = evaluate_line_pos + "evaluate_ast(ast)".size

# Create diagnostic with multiple specific spans
diagnostic2 = Hecate::Core::Diagnostic.new(
  Hecate::Core::Diagnostic::Severity::Info,
  "method has multiple responsibilities"
)
diagnostic2.primary(Hecate::Core::Span.new(source_id, tokenize_line_pos, tokenize_line_end), "tokenization responsibility")
diagnostic2.secondary(Hecate::Core::Span.new(source_id, parse_line_pos, parse_line_end), "parsing responsibility")
diagnostic2.secondary(Hecate::Core::Span.new(source_id, evaluate_line_pos, evaluate_line_end), "evaluation responsibility")
diagnostic2.help("split into separate methods: tokenize, parse, and evaluate")

renderer.emit(diagnostic2, source_map)
puts

# Example 3: Edge case - Labels at file boundaries
boundary_code = "x\ny\nz"
boundary_id = source_map.add_file("tiny.cr", boundary_code)

puts "3. File Boundary Labels:"
first_char = Hecate::Core::Span.new(boundary_id, 0, 1) # "x"
last_char = Hecate::Core::Span.new(boundary_id, 4, 5)  # "z"

diagnostic3 = Hecate::Core::Diagnostic.new(
  Hecate::Core::Diagnostic::Severity::Error,
  "undefined variables"
)
diagnostic3.primary(first_char, "not declared")
diagnostic3.secondary(last_char, "also not declared")

renderer.emit(diagnostic3, source_map)
puts

# Example 4: Different severity levels
puts "4. Various Severity Levels:"

# Create different diagnostics for each severity
severities = [
  {Hecate::Core::Diagnostic::Severity::Error, "critical error", "this will cause a crash"},
  {Hecate::Core::Diagnostic::Severity::Warning, "potential issue", "this might cause problems"},
  {Hecate::Core::Diagnostic::Severity::Info, "informational", "this is just for your information"},
  {Hecate::Core::Diagnostic::Severity::Hint, "suggestion", "you might want to consider this"},
]

severities.each do |severity, message, note|
  simple_span = Hecate::Core::Span.new(boundary_id, 2, 3) # "y"
  diag = Hecate::Core::Diagnostic.new(severity, message)
  diag.primary(simple_span, "here")
  diag.note(note)
  renderer.emit(diag, source_map)
  puts
end

puts "=== Demo Complete ==="
