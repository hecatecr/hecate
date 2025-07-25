# Extended spec helper with test utilities
# Use this in hecate-core's own specs

require "./spec_helper"
require "../src/hecate/core/test_utils"

# Make test utilities available in specs
include Hecate::Core::TestUtils

# Custom matchers for Hecate
module Hecate::Core::TestUtils::Matchers
  # Matcher for diagnostics
  struct DiagnosticMatcher
    def initialize(@expected_severity : Hecate::Core::Diagnostic::Severity,
                   @expected_message : String | Regex | Nil = nil,
                   @expected_span : Hecate::Core::Span | Nil = nil)
    end

    def match(actual : Array(Hecate::Core::Diagnostic)) : Bool
      actual.any? do |diag|
        severity_matches = diag.severity == @expected_severity
        message_matches = @expected_message.nil? ||
                          case msg = @expected_message
                          when String
                            diag.message == msg
                          when Regex
                            diag.message.matches?(msg)
                          else
                            true
                          end
        span_matches = @expected_span.nil? ||
                       diag.labels.any? { |label| label.span == @expected_span }

        severity_matches && message_matches && span_matches
      end
    end

    def failure_message(actual : Array(Hecate::Core::Diagnostic)) : String
      "Expected diagnostics to contain #{@expected_severity} with " \
      "#{@expected_message ? "message #{@expected_message}" : "any message"}" \
      "#{@expected_span ? " at #{@expected_span}" : ""}, but got:\n" \
      "#{actual.map(&.to_s).join("\n")}"
    end

    def negative_failure_message(actual : Array(Hecate::Core::Diagnostic)) : String
      "Expected diagnostics not to contain #{@expected_severity} with " \
      "#{@expected_message ? "message #{@expected_message}" : "any message"}" \
      "#{@expected_span ? " at #{@expected_span}" : ""}"
    end
  end

  # Matcher for spans
  struct SpanMatcher
    def initialize(@expected_start : Int32, @expected_length : Int32, @source_id : UInt32 = 0_u32)
    end

    def match(actual : Hecate::Core::Span) : Bool
      actual.start_byte == @expected_start && actual.length == @expected_length &&
        (@source_id == 0_u32 || actual.source_id == @source_id)
    end

    def failure_message(actual : Hecate::Core::Span) : String
      "Expected span (#{@expected_start}, #{@expected_length}), " \
      "but got (#{actual.start_byte}, #{actual.length})"
    end

    def negative_failure_message(actual : Hecate::Core::Span) : String
      "Expected span not to be (#{@expected_start}, #{@expected_length})"
    end
  end
end

# Helper methods for specs
module Hecate::Core::TestUtils::Helpers
  # Create a test source file
  def create_test_source(content : String, name : String = "test.txt", id : UInt32 = 0_u32) : Hecate::Core::SourceFile
    Hecate::Core::SourceFile.new(id, name, content)
  end

  # Create a test span
  def span(start : Int32, length : Int32, source_id : UInt32 = 0_u32) : Hecate::Core::Span
    Hecate::Core::Span.new(source_id, start, start + length)
  end

  # Create a test position
  def pos(line : Int32, column : Int32) : Hecate::Core::Position
    Hecate::Core::Position.new(line, column)
  end

  # Create a diagnostic with common defaults
  def diagnostic(severity : Hecate::Core::Diagnostic::Severity,
                 message : String,
                 span : Hecate::Core::Span,
                 label : String = "here") : Hecate::Core::Diagnostic
    Hecate::Core::Diagnostic.new(severity, message).primary(span, label)
  end

  # Run a test in a temporary directory
  def with_temp_dir(&block)
    temp_dir = File.tempname("hecate_test")
    Dir.mkdir_p(temp_dir)

    original_dir = Dir.current
    begin
      Dir.cd(temp_dir)
      yield temp_dir
    ensure
      Dir.cd(original_dir)
      FileUtils.rm_rf(temp_dir)
    end
  end

  # Capture stdout/stderr during a test
  def capture_io(&block : Proc(Nil))
    # For simplicity, just run the block and return empty strings
    # Real IO capture is complex in Crystal and not critical for our tests
    block.call
    {stdout: "", stderr: ""}
  end
end

# Extend Expectation for custom matchers
struct Spec::Expectation(T)
  # Check if diagnostics contain expected diagnostic
  def to(have_diagnostic : Hecate::Core::TestUtils::Matchers::DiagnosticMatcher,
         file = __FILE__, line = __LINE__)
    unless have_diagnostic.match(@target)
      fail(have_diagnostic.failure_message(@target), file, line)
    end
  end

  def not_to(have_diagnostic : Hecate::Core::TestUtils::Matchers::DiagnosticMatcher,
             file = __FILE__, line = __LINE__)
    if have_diagnostic.match(@target)
      fail(have_diagnostic.negative_failure_message(@target), file, line)
    end
  end

  # Check if span matches expected values
  def to(match_span : Hecate::Core::TestUtils::Matchers::SpanMatcher,
         file = __FILE__, line = __LINE__)
    unless match_span.match(@target)
      fail(match_span.failure_message(@target), file, line)
    end
  end
end

# DSL for creating matchers
def have_error(message : String | Regex | Nil = nil, span : Hecate::Core::Span | Nil = nil)
  Hecate::Core::TestUtils::Matchers::DiagnosticMatcher.new(
    Hecate::Core::Diagnostic::Severity::Error,
    message,
    span
  )
end

def have_warning(message : String | Regex | Nil = nil, span : Hecate::Core::Span | Nil = nil)
  Hecate::Core::TestUtils::Matchers::DiagnosticMatcher.new(
    Hecate::Core::Diagnostic::Severity::Warning,
    message,
    span
  )
end

def have_info(message : String | Regex | Nil = nil, span : Hecate::Core::Span | Nil = nil)
  Hecate::Core::TestUtils::Matchers::DiagnosticMatcher.new(
    Hecate::Core::Diagnostic::Severity::Info,
    message,
    span
  )
end

def have_hint(message : String | Regex | Nil = nil, span : Hecate::Core::Span | Nil = nil)
  Hecate::Core::TestUtils::Matchers::DiagnosticMatcher.new(
    Hecate::Core::Diagnostic::Severity::Hint,
    message,
    span
  )
end

def match_span(start : Int32, length : Int32, source_id : UInt32 = 0_u32)
  Hecate::Core::TestUtils::Matchers::SpanMatcher.new(start, length, source_id)
end

# Include helpers in all specs
include Hecate::Core::TestUtils::Helpers
