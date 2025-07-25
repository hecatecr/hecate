require "../../../spec_helper"

describe Hecate::Core::TTYRenderer do
  describe "#emit" do
    it "renders a simple error diagnostic" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)

      # Add source file
      source_content = "let x = 42;\nlet y = x + 1;"
      source_id = source_map.add_file("test.cr", source_content)

      # Create span pointing to 'x' in first line
      span = Hecate::Core::Span.new(source_id, 4, 5)

      # Create diagnostic
      diagnostic = Hecate::Core::Diagnostic.new(
        Hecate::Core::Diagnostic::Severity::Error,
        "undefined variable"
      )
      diagnostic.primary(span, "not found")

      # Render
      renderer.emit(diagnostic, source_map)

      result = output.to_s
      result.should contain("error: undefined variable")
      result.should contain("test.cr:1:5")
      result.should contain("let x = 42;")
      result.should contain("^")
      result.should contain("not found")
    end

    it "renders diagnostics with multiple labels" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)

      source_content = "let x = 42;\nlet y = x + 1;\nlet z = y * 2;"
      source_id = source_map.add_file("multi.cr", source_content)

      # Create spans for different variables
      span_x = Hecate::Core::Span.new(source_id, 4, 5)   # 'x' in line 1
      span_y = Hecate::Core::Span.new(source_id, 16, 17) # 'y' in line 2

      diagnostic = Hecate::Core::Diagnostic.new(
        Hecate::Core::Diagnostic::Severity::Warning,
        "unused variables"
      )
      diagnostic.primary(span_x, "first unused")
      diagnostic.secondary(span_y, "also unused")

      renderer.emit(diagnostic, source_map)

      result = output.to_s
      result.should contain("warning: unused variables")
      result.should contain("let x = 42;")
      result.should contain("let y = x + 1;")
      result.should contain("^") # primary label
      result.should contain("~") # secondary label
      result.should contain("first unused")
      result.should contain("also unused")
    end

    it "handles help and notes" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)

      source_content = "let x = 42;"
      source_id = source_map.add_file("help.cr", source_content)
      span = Hecate::Core::Span.new(source_id, 4, 5)

      diagnostic = Hecate::Core::Diagnostic.new(
        Hecate::Core::Diagnostic::Severity::Error,
        "syntax error"
      )
      diagnostic.primary(span, "unexpected token")
      diagnostic.help("try adding a semicolon")
      diagnostic.note("this is just a suggestion")
      diagnostic.note("you might also consider refactoring")

      renderer.emit(diagnostic, source_map)

      result = output.to_s
      result.should contain("help: try adding a semicolon")
      result.should contain("note: this is just a suggestion")
      result.should contain("note: you might also consider refactoring")
    end

    it "handles empty labels gracefully" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)

      source_content = "let x = 42;"
      source_id = source_map.add_file("empty.cr", source_content)
      span = Hecate::Core::Span.new(source_id, 4, 5)

      diagnostic = Hecate::Core::Diagnostic.new(
        Hecate::Core::Diagnostic::Severity::Error,
        "error message"
      )
      diagnostic.primary(span, "") # Empty label message

      renderer.emit(diagnostic, source_map)

      result = output.to_s
      result.should contain("error: error message")
      result.should contain("let x = 42;")
      result.should contain("^")
    end

    it "handles overlapping labels on same line" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)

      source_content = "let variable_name = 42;"
      source_id = source_map.add_file("overlap.cr", source_content)

      # Overlapping spans on the same line
      span1 = Hecate::Core::Span.new(source_id, 4, 12) # "variable"
      span2 = Hecate::Core::Span.new(source_id, 8, 17) # "able_name"

      diagnostic = Hecate::Core::Diagnostic.new(
        Hecate::Core::Diagnostic::Severity::Warning,
        "overlapping spans"
      )
      diagnostic.primary(span1, "first span")
      diagnostic.secondary(span2, "second span")

      renderer.emit(diagnostic, source_map)

      result = output.to_s
      result.should contain("warning: overlapping spans")
      result.should contain("let variable_name = 42;")
      result.should contain("^")
      result.should contain("~")
      result.should contain("first span")
      result.should contain("second span")
    end

    it "handles labels at line boundaries" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)

      source_content = "a\nb\nc"
      source_id = source_map.add_file("boundaries.cr", source_content)

      # Label at end of first line
      span1 = Hecate::Core::Span.new(source_id, 0, 1) # "a"
      # Label at start of last line
      span2 = Hecate::Core::Span.new(source_id, 4, 5) # "c"

      diagnostic = Hecate::Core::Diagnostic.new(
        Hecate::Core::Diagnostic::Severity::Info,
        "boundary labels"
      )
      diagnostic.primary(span1, "first char")
      diagnostic.secondary(span2, "last char")

      renderer.emit(diagnostic, source_map)

      result = output.to_s
      result.should contain("info: boundary labels")
      result.should contain("^ first char")
      result.should contain("~ last char")
    end

    it "calculates context lines correctly with gaps" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)

      # Multi-line source with labels far apart
      lines = (1..20).map { |i| "line #{i}" }
      source_content = lines.join("\n")
      source_id = source_map.add_file("context.cr", source_content)

      # Labels on lines 2 and 18 (far apart)
      line2_offset = source_content.index("line 2").not_nil!
      line18_offset = source_content.index("line 18").not_nil!

      span1 = Hecate::Core::Span.new(source_id, line2_offset, line2_offset + 6)
      span2 = Hecate::Core::Span.new(source_id, line18_offset, line18_offset + 7)

      diagnostic = Hecate::Core::Diagnostic.new(
        Hecate::Core::Diagnostic::Severity::Error,
        "distant labels"
      )
      diagnostic.primary(span1, "early")
      diagnostic.secondary(span2, "late")

      renderer.emit(diagnostic, source_map)

      result = output.to_s

      # Should show context around both labels (lines 1-4 and 16-20)
      result.should contain("line 1")  # Context before line 2
      result.should contain("line 2")  # First label line
      result.should contain("line 4")  # Context after line 2
      result.should contain("line 16") # Context before line 18
      result.should contain("line 18") # Second label line
      result.should contain("line 20") # Context after line 18

      # Should show all intermediate lines too due to context merging
      result.should contain("line 10") # Should be included in range
    end
  end

  describe "NO_COLOR environment handling" do
    it "initializes with NO_COLOR awareness" do
      source_map = Hecate::Core::SourceMap.new
      output = IO::Memory.new

      # Test that NO_COLOR is checked during initialization
      old_env = ENV["NO_COLOR"]?

      begin
        ENV["NO_COLOR"] = "1"
        renderer_with_no_color = Hecate::Core::TTYRenderer.new(output)

        ENV.delete("NO_COLOR")
        renderer_without_no_color = Hecate::Core::TTYRenderer.new(output)

        # Both should work without errors
        source_content = "test"
        source_id = source_map.add_file("test.cr", source_content)
        span = Hecate::Core::Span.new(source_id, 0, 4)
        diagnostic = Hecate::Core::Diagnostic.new(
          Hecate::Core::Diagnostic::Severity::Error,
          "test"
        )
        diagnostic.primary(span)

        renderer_with_no_color.emit(diagnostic, source_map)
        output.clear
        renderer_without_no_color.emit(diagnostic, source_map)
      ensure
        if old_env
          ENV["NO_COLOR"] = old_env
        else
          ENV.delete("NO_COLOR")
        end
      end
    end
  end
end
