require "../../../test_spec_helper"

def capture_tty_output(
  diagnostic : Hecate::Core::Diagnostic,
  source_map : Hecate::Core::SourceMap,
  terminal_width : Int32 = 80
) : String
  output = IO::Memory.new
  renderer = Hecate::Core::TTYRenderer.new(output, terminal_width)
  renderer.emit(diagnostic, source_map)
  output.to_s
end

describe "TTY Renderer Snapshots" do
  
  describe "basic diagnostics" do
    it "renders a simple error" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "let x = 42;\nlet y = x + 1;"
      source_id = source_map.add_file("simple.cr", source_content)
      
      diag = Hecate::Core.error("undefined variable")
        .primary(Hecate::Core::Span.new(source_id, 4, 5), "not found")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/simple_error", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders warning with multiple labels" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "let x = 42;\nlet y = x + 1;\nlet z = y * 2;"
      source_id = source_map.add_file("multi.cr", source_content)
      
      diag = Hecate::Core.warning("unused variables")
        .primary(Hecate::Core::Span.new(source_id, 4, 5), "first unused")
        .secondary(Hecate::Core::Span.new(source_id, 16, 17), "also unused")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/warning_multiple_labels", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders info with help and notes" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "let x = 42;"
      source_id = source_map.add_file("help.cr", source_content)
      
      diag = Hecate::Core.info("syntax suggestion")
        .primary(Hecate::Core::Span.new(source_id, 4, 5), "consider renaming")
        .help("try using a more descriptive name")
        .note("descriptive names improve code readability")
        .note("avoid single-letter variables in production code")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/info_with_help_notes", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders hint diagnostic" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "def add(a, b)\n  a + b\nend"
      source_id = source_map.add_file("hint.cr", source_content)
      
      diag = Hecate::Core.hint("type annotations missing")
        .primary(Hecate::Core::Span.new(source_id, 8, 13), "parameters lack type annotations")
        .help("add type annotations for better type safety")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/hint_type_annotations", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
  end
  
  describe "multi-line diagnostics" do
    it "renders diagnostic spanning multiple lines" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "def process\n  start_transaction\n  do_work\n  commit\nend"
      source_id = source_map.add_file("multiline.cr", source_content)
      
      # Span covering the entire function body (lines 2-4)
      diag = Hecate::Core.error("missing error handling")
        .primary(Hecate::Core::Span.new(source_id, 13, 40), "transaction not properly wrapped")
        .help("wrap in begin/rescue block")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/multiline_span", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders overlapping spans on same line" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "let very_long_variable_name = compute_value();"
      source_id = source_map.add_file("overlap.cr", source_content)
      
      diag = Hecate::Core.warning("naming conventions")
        .primary(Hecate::Core::Span.new(source_id, 4, 23), "snake_case preferred")
        .secondary(Hecate::Core::Span.new(source_id, 14, 27), "too verbose")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/overlapping_spans", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders distant labels with context" do
      source_map = Hecate::Core::SourceMap.new
      lines = (1..20).map { |i| "// Line #{i.to_s.rjust(2, '0')}: code here" }
      source_content = lines.join("\n")
      source_id = source_map.add_file("distant.cr", source_content)
      
      # Labels on lines 3 and 17 (far apart)
      line3_offset = lines[0..2].join("\n").size + 1  # +1 for newline
      line17_offset = lines[0..16].join("\n").size + 1
      
      diag = Hecate::Core.error("related errors")
        .primary(Hecate::Core::Span.new(source_id, line3_offset + 3, line3_offset + 10), "first issue here")
        .secondary(Hecate::Core::Span.new(source_id, line17_offset + 3, line17_offset + 10), "caused by this")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/distant_labels", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
  end
  
  describe "edge cases" do
    it "renders empty file diagnostic" do
      source_map = Hecate::Core::SourceMap.new
      source_content = ""
      source_id = source_map.add_file("empty.cr", source_content)
      
      diag = Hecate::Core.error("empty file")
        .primary(Hecate::Core::Span.new(source_id, 0, 0), "file is empty")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/empty_file", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders very long lines" do
      source_map = Hecate::Core::SourceMap.new
      long_line = "let x = " + ("very_" * 20) + "long_variable_name;"
      source_id = source_map.add_file("long.cr", long_line)
      
      diag = Hecate::Core.warning("line too long")
        .primary(Hecate::Core::Span.new(source_id, 80, 100), "exceeds recommended length")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/long_line", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders unicode content correctly" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "let café = \"☕\";\nlet 数値 = 42;"
      source_id = source_map.add_file("unicode.cr", source_content)
      
      diag = Hecate::Core.info("unicode identifiers")
        .primary(Hecate::Core::Span.new(source_id, 4, 8), "non-ASCII identifier")
        .secondary(Hecate::Core::Span.new(source_id, 19, 23), "also non-ASCII")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/unicode_content", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders with different terminal widths" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "function calculateComplexValue(parameter1, parameter2, parameter3) { return parameter1 + parameter2 * parameter3; }"
      source_id = source_map.add_file("width.cr", source_content)
      
      diag = Hecate::Core.error("too many parameters")
        .primary(Hecate::Core::Span.new(source_id, 30, 66), "consider using an options object")
        .build
      
      # Test with narrow terminal
      narrow_output = capture_tty_output(diag, source_map, 60)
      Hecate::Core::TestUtils::Snapshot.match("tty/narrow_terminal", narrow_output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
      
      # Test with wide terminal
      wide_output = capture_tty_output(diag, source_map, 120)
      Hecate::Core::TestUtils::Snapshot.match("tty/wide_terminal", wide_output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders CRLF line endings correctly" do
      source_map = Hecate::Core::SourceMap.new
      # Use CRLF line endings
      source_content = "line one\r\nline two\r\nline three"
      source_id = source_map.add_file("crlf.cr", source_content)
      
      diag = Hecate::Core.error("line ending issue")
        .primary(Hecate::Core::Span.new(source_id, 10, 18), "second line")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/crlf_endings", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
  end
  
  describe "complex scenarios" do
    it "renders multiple diagnostics in sequence" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "fn main() {\n  let x = undefined;\n  let y = x + 1;\n  print(z);\n}"
      source_id = source_map.add_file("multiple.cr", source_content)
      
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)
      
      # First diagnostic
      diag1 = Hecate::Core.error("undefined is not a value")
        .primary(Hecate::Core::Span.new(source_id, 22, 31), "not defined")
        .build
      renderer.emit(diag1, source_map)
      
      # Second diagnostic  
      diag2 = Hecate::Core.warning("potential null reference")
        .primary(Hecate::Core::Span.new(source_id, 41, 42), "x might be null")
        .build
      renderer.emit(diag2, source_map)
      
      # Third diagnostic
      diag3 = Hecate::Core.error("undefined variable")
        .primary(Hecate::Core::Span.new(source_id, 57, 58), "z is not defined")
        .help("did you mean 'x' or 'y'?")
        .build
      renderer.emit(diag3, source_map)
      
      Hecate::Core::TestUtils::Snapshot.match("tty/multiple_diagnostics", output.to_s, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders diagnostic with all severity levels" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "// Error line\n// Warning line\n// Info line\n// Hint line"
      source_id = source_map.add_file("severity.cr", source_content)
      
      output = IO::Memory.new
      renderer = Hecate::Core::TTYRenderer.new(output, 80)
      
      # Error
      error_diag = Hecate::Core.error("this is an error")
        .primary(Hecate::Core::Span.new(source_id, 3, 8), "error here")
        .build
      renderer.emit(error_diag, source_map)
      
      # Warning
      warning_diag = Hecate::Core.warning("this is a warning")
        .primary(Hecate::Core::Span.new(source_id, 17, 24), "warning here")
        .build
      renderer.emit(warning_diag, source_map)
      
      # Info
      info_diag = Hecate::Core.info("this is info")
        .primary(Hecate::Core::Span.new(source_id, 33, 37), "info here")
        .build
      renderer.emit(info_diag, source_map)
      
      # Hint
      hint_diag = Hecate::Core.hint("this is a hint")
        .primary(Hecate::Core::Span.new(source_id, 47, 51), "hint here")
        .build
      renderer.emit(hint_diag, source_map)
      
      Hecate::Core::TestUtils::Snapshot.match("tty/all_severities", output.to_s, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
    
    it "renders multi-file diagnostic" do
      source_map = Hecate::Core::SourceMap.new
      
      # Create multiple source files
      source1_content = "require \"./helper\"\n\nhelper_function()"
      source1_id = source_map.add_file("main.cr", source1_content)
      
      source2_content = "def helper_function\n  undefined_method()\nend"
      source2_id = source_map.add_file("helper.cr", source2_content)
      
      diag = Hecate::Core.error("undefined method 'undefined_method'")
        .primary(Hecate::Core::Span.new(source2_id, 24, 41), "method not found")
        .secondary(Hecate::Core::Span.new(source1_id, 20, 35), "called from here")
        .help("did you forget to define this method?")
        .build
      
      output = capture_tty_output(diag, source_map)
      Hecate::Core::TestUtils::Snapshot.match("tty/multi_file", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
    end
  end
  
  describe "NO_COLOR environment" do
    it "renders without color when NO_COLOR is set" do
      source_map = Hecate::Core::SourceMap.new
      source_content = "let x = error;"
      source_id = source_map.add_file("nocolor.cr", source_content)
      
      diag = Hecate::Core.error("undefined variable 'error'")
        .primary(Hecate::Core::Span.new(source_id, 8, 13), "not defined")
        .build
      
      old_env = ENV["NO_COLOR"]?
      begin
        ENV["NO_COLOR"] = "1"
        output = capture_tty_output(diag, source_map)
        Hecate::Core::TestUtils::Snapshot.match("tty/no_color", output, update: ENV["UPDATE_SNAPSHOTS"]? == "1")
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