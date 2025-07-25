require "../test_spec_helper"

describe "Language Pipeline Integration Tests" do
  # These tests demonstrate how the different Hecate components work together
  # in a realistic language processing pipeline

  describe "Simple Expression Language" do
    it "processes valid expressions end-to-end" do
      # This test demonstrates the complete flow:
      # Source Code -> SourceMap -> Lexer -> Parser -> Diagnostics -> Rendering

      source_code = "let x = 42 + (3 * y);"

      # Step 1: Create source map and add source
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("expression.lang", source_code)
      source_file = source_map.get(source_id).not_nil!

      # Step 2: Verify source file properties
      source_file.path.should eq("expression.lang")
      source_file.contents.should eq(source_code)
      source_file.line_offsets.size.should eq(1)

      # Step 3: Test position calculations
      position_at_x = source_file.byte_to_position(4) # Position of 'x'
      position_at_x.line.should eq(0)
      position_at_x.column.should eq(4)

      position_at_y = source_file.byte_to_position(18) # Position of 'y'
      position_at_y.line.should eq(0)
      position_at_y.column.should eq(18)

      # Step 4: Create spans for different elements
      let_span = Hecate::Core::Span.new(source_id, 0, 3)   # "let"
      x_span = Hecate::Core::Span.new(source_id, 4, 5)     # "x"
      expr_span = Hecate::Core::Span.new(source_id, 8, 20) # "42 + (3 * y)"

      # Step 5: Test span operations
      let_text = source_file.contents[let_span.start_byte...let_span.end_byte]
      let_text.should eq("let")

      x_text = source_file.contents[x_span.start_byte...x_span.end_byte]
      x_text.should eq("x")

      expr_text = source_file.contents[expr_span.start_byte...expr_span.end_byte]
      expr_text.should eq("42 + (3 * y)")

      # Step 6: Test diagnostic creation and rendering
      success_diagnostic = Hecate::Core.info("expression parsed successfully")
        .primary(expr_span, "valid expression")
        .help("expression evaluates to: 42 + (3 * y)")
        .build

      success_diagnostic.severity.should eq(Hecate::Core::Diagnostic::Severity::Info)
      success_diagnostic.message.should eq("expression parsed successfully")
      success_diagnostic.labels.size.should eq(1)
      success_diagnostic.help.should eq("expression evaluates to: 42 + (3 * y)")

      # Step 7: Test diagnostic rendering
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)
      renderer.emit(success_diagnostic, source_map)

      rendered_output = output.to_s
      rendered_output.should contain("info: expression parsed successfully")
      rendered_output.should contain("expression.lang:1:9")
      rendered_output.should contain("42 + (3 * y)")
      rendered_output.should contain("valid expression")
      rendered_output.should contain("help: expression evaluates to")
    end

    it "handles syntax errors with helpful diagnostics" do
      # Test error case: missing semicolon
      source_code = "let x = 42 + (3 * y)" # Missing semicolon

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("error.lang", source_code)
      source_file = source_map.get(source_id).not_nil!

      # Create error diagnostic for missing semicolon
      end_span = Hecate::Core::Span.new(source_id, 19, 20) # End of expression

      error_diagnostic = Hecate::Core.error("expected ';' after expression")
        .primary(end_span, "missing semicolon")
        .help("add ';' to terminate the statement")
        .note("all statements must end with a semicolon")
        .build

      error_diagnostic.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      error_diagnostic.message.should eq("expected ';' after expression")

      # Test error rendering
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)
      renderer.emit(error_diagnostic, source_map)

      rendered_output = output.to_s
      rendered_output.should contain("error: expected ';' after expression")
      rendered_output.should contain("missing semicolon")
      rendered_output.should contain("help: add ';' to terminate")
      rendered_output.should contain("note: all statements must end")
    end

    it "handles multi-line source with complex diagnostics" do
      source_code = <<-CODE
      function fibonacci(n) {
        if (n <= 1) {
          return n;
        } else {
          return fibonacci(n - 1) + fibonacci(n - 2);
        }
      }
      
      let result = fibonacci(undefined_var);
      CODE

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("fibonacci.lang", source_code)
      source_file = source_map.get(source_id).not_nil!

      # Test multi-line source properties
      source_file.line_offsets.size.should eq(9)

      # Find position of undefined_var (should be on line 8, around column 25)
      undefined_pos = source_code.index("undefined_var").not_nil!
      position = source_file.byte_to_position(undefined_pos)
      position.line.should eq(8) # 0-based line indexing

      # Create spans for the diagnostic
      undefined_span = Hecate::Core::Span.new(source_id, undefined_pos, undefined_pos + 13)
      function_def_span = Hecate::Core::Span.new(source_id, 0, 8) # "function"

      # Create a comprehensive diagnostic
      diagnostic = Hecate::Core.error("undefined variable 'undefined_var'")
        .primary(undefined_span, "variable not found")
        .secondary(function_def_span, "function defined here")
        .help("declare the variable before use, or use a defined parameter")
        .note("variables must be declared before they can be used")
        .note("check for typos in variable names")
        .build

      diagnostic.labels.size.should eq(2)
      diagnostic.help.should eq("declare the variable before use, or use a defined parameter")
      diagnostic.notes.size.should eq(2)

      # Test rendering of multi-line diagnostic
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 120) # Wider terminal
      renderer.emit(diagnostic, source_map)

      rendered_output = output.to_s
      rendered_output.should contain("error: undefined variable")
      rendered_output.should contain("fibonacci.lang") # Just check filename for now
      rendered_output.should contain("undefined_var")
      rendered_output.should contain("variable not found")
      rendered_output.should contain("function defined here")
      rendered_output.should contain("help: declare the variable")
      rendered_output.should contain("note: variables must be declared")
      rendered_output.should contain("note: check for typos")
    end

    it "tests line offset calculations with different line endings" do
      # Test CRLF line endings
      crlf_source = "line 1\r\nline 2\r\nline 3\r\n"
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("crlf.txt", crlf_source)
      source_file = source_map.get(source_id).not_nil!

      source_file.line_offsets.size.should eq(4) # 3 lines + final empty line

      # Test positions
      line2_start = source_file.byte_to_position(8) # Start of "line 2"
      line2_start.line.should eq(1)
      line2_start.column.should eq(0)

      line3_start = source_file.byte_to_position(16) # Start of "line 3"
      line3_start.line.should eq(2)
      line3_start.column.should eq(0)

      # Test LF line endings
      lf_source = "line 1\nline 2\nline 3\n"
      lf_source_id = source_map.add_file("lf.txt", lf_source)
      lf_source_file = source_map.get(lf_source_id).not_nil!

      lf_source_file.line_offsets.size.should eq(4)

      lf_line2_start = lf_source_file.byte_to_position(7) # Start of "line 2"
      lf_line2_start.line.should eq(1)
      lf_line2_start.column.should eq(0)
    end

    it "tests performance with reasonably large input" do
      # Generate a larger source file to test performance
      lines = [] of String
      500.times do |i|
        lines << "let var#{i} = #{i} + #{i + 1};"
      end
      large_source = lines.join("\n")

      source_map = Hecate::Core::SourceMap.new

      # Measure time for adding large source
      start_time = Time.monotonic
      source_id = source_map.add_file("large.lang", large_source)
      source_file = source_map.get(source_id).not_nil!
      add_time = Time.monotonic - start_time

      # Should be very fast (under 10ms for this size)
      add_time.should be < 10.milliseconds

      source_file.line_offsets.size.should eq(500)

      # Test position calculation performance
      start_time = Time.monotonic
      100.times do |i|
        pos = Random.rand(large_source.size)
        source_file.byte_to_position(pos)
      end
      position_time = Time.monotonic - start_time

      # Position calculations should also be fast
      position_time.should be < 5.milliseconds

      # Test diagnostic creation with the large source
      middle_pos = large_source.size // 2
      span = Hecate::Core::Span.new(source_id, middle_pos, middle_pos + 10)

      diagnostic = Hecate::Core.info("performance test")
        .primary(span, "middle of large file")
        .build

      diagnostic.should_not be_nil
      diagnostic.labels.first.span.should eq(span)
    end
  end

  describe "Edge Cases and Error Conditions" do
    it "handles empty source files" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("empty.txt", "")
      source_file = source_map.get(source_id).not_nil!

      source_file.contents.should eq("")
      source_file.line_offsets.size.should eq(1)

      # Position at start should work
      pos = source_file.byte_to_position(0)
      pos.line.should eq(0)
      pos.column.should eq(0)

      # Create diagnostic for empty file
      empty_span = Hecate::Core::Span.new(source_id, 0, 0)
      diagnostic = Hecate::Core.error("empty file")
        .primary(empty_span, "file contains no content")
        .build

      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)
      renderer.emit(diagnostic, source_map)

      rendered_output = output.to_s
      rendered_output.should contain("error: empty file")
    end

    it "handles files with only whitespace" do
      whitespace_source = "   \n\t\n  \r\n  "

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("whitespace.txt", whitespace_source)
      source_file = source_map.get(source_id).not_nil!

      source_file.line_offsets.size.should eq(4)

      # Test position calculations in whitespace
      tab_pos = source_file.byte_to_position(4) # Position of tab
      tab_pos.line.should eq(1)
      tab_pos.column.should eq(0)
    end

    it "handles unicode content correctly" do
      unicode_source = "let café = \"☕\";\nlet 数値 = 42;"

      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("unicode.lang", unicode_source)
      source_file = source_map.get(source_id).not_nil!

      source_file.line_offsets.size.should eq(2)

      # Create diagnostic for unicode identifier
      cafe_pos = unicode_source.index("café").not_nil!
      cafe_span = Hecate::Core::Span.new(source_id, cafe_pos, cafe_pos + 4)

      diagnostic = Hecate::Core.info("unicode identifier detected")
        .primary(cafe_span, "non-ASCII characters in identifier")
        .help("unicode identifiers are supported")
        .build

      # Test that rendering works with unicode
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)
      renderer.emit(diagnostic, source_map)

      rendered_output = output.to_s
      rendered_output.should contain("café")
      rendered_output.should contain("unicode identifier")
    end
  end
end
