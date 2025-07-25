require "../src/hecate-core"

# Create a source map and add a sample file
source_map = Hecate::Core::SourceMap.new
sample_code = <<-CODE
def calculate(x, y)
  result = x + y * 2
  puts result
end

def main
  calculate(10, 20)
end
CODE

source_id = source_map.add_file("sample.cr", sample_code)

# Create a TTY renderer
renderer = Hecate::Core::TTYRenderer.new(STDOUT, 80)

# Example 1: Simple error with primary label
puts "=== Example 1: Simple Error ==="
span1 = Hecate::Core::Span.new(source_id, 14, 15) # 'x' parameter
diagnostic1 = Hecate::Core::Diagnostic.new(
  Hecate::Core::Diagnostic::Severity::Error,
  "undefined variable"
)
diagnostic1.primary(span1, "not found in scope")
diagnostic1.help("try declaring the variable first")

renderer.emit(diagnostic1, source_map)
puts

# Example 2: Warning with multiple labels
puts "=== Example 2: Multiple Labels ==="
span2a = Hecate::Core::Span.new(source_id, 14, 15) # 'x' parameter
span2b = Hecate::Core::Span.new(source_id, 17, 18) # 'y' parameter
diagnostic2 = Hecate::Core::Diagnostic.new(
  Hecate::Core::Diagnostic::Severity::Warning,
  "unused parameters"
)
diagnostic2.primary(span2a, "parameter never used")
diagnostic2.secondary(span2b, "also unused")
diagnostic2.note("consider removing unused parameters")

renderer.emit(diagnostic2, source_map)
puts

# Example 3: Multi-line span
puts "=== Example 3: Multi-line Span ==="
# Span covering the entire function body
function_body_start = sample_code.index("result = x + y * 2").not_nil!
function_body_end = sample_code.index("end", function_body_start).not_nil!
span3 = Hecate::Core::Span.new(source_id, function_body_start, function_body_end)

diagnostic3 = Hecate::Core::Diagnostic.new(
  Hecate::Core::Diagnostic::Severity::Info,
  "complex function"
)
diagnostic3.primary(span3, "this function does multiple things")
diagnostic3.help("consider splitting into smaller functions")
diagnostic3.note("functions should have a single responsibility")

renderer.emit(diagnostic3, source_map)
