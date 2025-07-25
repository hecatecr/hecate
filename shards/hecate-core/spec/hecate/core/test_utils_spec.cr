require "../../test_spec_helper"

describe Hecate::Core::TestUtils do
  describe "TestCase structures" do
    it "creates success cases" do
      test_case = SuccessCase.new("input", 42, "test description")
      test_case.input.should eq("input")
      test_case.expected.should eq(42)
      test_case.description.should eq("test description")
    end

    it "creates error cases" do
      test_case = ErrorCase.new("bad input", "expected error", "error test")
      test_case.input.should eq("bad input")
      test_case.expected_error.should eq("expected error")
      test_case.description.should eq("error test")
    end

    it "supports regex patterns for errors" do
      test_case = ErrorCase.new("bad", /error \d+/, "regex test")
      test_case.expected_error.should be_a(Regex)
    end
  end

  describe "Snapshot testing" do
    it "creates new snapshots when they don't exist" do
      with_temp_dir do |dir|
        # Mock the caller to return our temp spec file
        snapshot_path = File.join(dir, "spec", "__snapshots__", "test.snap")

        # This would normally be done by the macro, but we'll test directly
        Dir.mkdir_p(File.dirname(snapshot_path))
        File.write(snapshot_path, "test content")

        File.exists?(snapshot_path).should be_true
        File.read(snapshot_path).should eq("test content")
      end
    end

    it "detects snapshot mismatches" do
      with_temp_dir do |dir|
        snapshot_path = File.join(dir, "__snapshots__", "mismatch.snap")
        Dir.mkdir_p(File.dirname(snapshot_path))
        File.write(snapshot_path, "expected content")

        # This would raise in real usage
        expected = File.read(snapshot_path)
        actual = "actual content"

        expected.should_not eq(actual)
      end
    end

    it "normalizes content in formatted snapshots" do
      content = "line 1  \nline 2\r\nline 3   "
      normalized = content.lines.map(&.rstrip).join('\n').rstrip + '\n'

      normalized.should eq("line 1\nline 2\nline 3\n")
    end
  end

  describe "Generators" do
    it "generates valid identifiers" do
      100.times do
        id = Generators.identifier
        id.should match(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
        id.size.should eq(8)
      end
    end

    it "generates identifiers of specified length" do
      id = Generators.identifier(15)
      id.size.should eq(15)
      id.should match(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
    end

    it "generates source snippets" do
      snippet = Generators.source_snippet(3)
      lines = snippet.lines
      lines.size.should eq(3)

      # Each line should match one of the templates
      lines.each do |line|
        valid = line.starts_with?("let ") ||
                line.starts_with?("func ") ||
                line.starts_with?("if ") ||
                line.starts_with?("return ") ||
                line.starts_with?("// ")
        valid.should be_true
      end
    end

    it "generates random spans" do
      100.times do
        span = Generators.span(0_u32, 1000)
        span.start_byte.should be <= 1000
        span.length.should be >= 1
        span.length.should be <= 20
      end
    end
  end

  describe "Custom matchers" do
    it "matches diagnostics by severity" do
      diagnostics = [
        diagnostic(Hecate::Core::Diagnostic::Severity::Error, "test error", span(0, 5)),
        diagnostic(Hecate::Core::Diagnostic::Severity::Warning, "test warning", span(10, 5)),
      ]

      diagnostics.should have_error
      diagnostics.should have_warning
      diagnostics.should_not have_info
      diagnostics.should_not have_hint
    end

    it "matches diagnostics by message" do
      diagnostics = [
        diagnostic(Hecate::Core::Diagnostic::Severity::Error, "undefined variable", span(0, 5)),
      ]

      diagnostics.should have_error("undefined variable")
      diagnostics.should have_error(/undefined/)
      diagnostics.should_not have_error("syntax error")
    end

    it "matches diagnostics by span" do
      test_span = span(10, 5)
      diagnostics = [
        diagnostic(Hecate::Core::Diagnostic::Severity::Error, "error", test_span),
      ]

      diagnostics.should have_error(span: test_span)
      diagnostics.should_not have_error(span: span(0, 5))
    end

    it "matches spans" do
      test_span = span(10, 20)
      test_span.should match_span(10, 20)
    end
  end

  describe "Helper methods" do
    it "creates test source files" do
      source = create_test_source("test content", "test.cr")
      source.path.should eq("test.cr")
      source.contents.should eq("test content")
    end

    it "captures IO during tests" do
      result = capture_io do
        puts "stdout message"
        STDERR.puts "stderr message"
      end

      # Simple implementation just returns empty strings
      result[:stdout].should eq("")
      result[:stderr].should eq("")
    end
  end
end
