require "./spec_helper"

describe Hecate::Lex do
  it "has a version" do
    Hecate::Lex::VERSION.should be_a(String)
  end

  describe "test utilities integration" do
    it "can create test spans" do
      test_span = span(10, 5)
      test_span.should be_a(Hecate::Core::Span)
      test_span.start_byte.should eq(10)
      test_span.length.should eq(5)
    end

    it "can create test source files" do
      source = create_test_source("test content", "test.lex")
      source.should be_a(Hecate::Core::SourceFile)
      source.path.should eq("test.lex")
      source.contents.should eq("test content")
    end

    it "can create diagnostics" do
      diag = diagnostic(
        Hecate::Core::Diagnostic::Severity::Error,
        "test error",
        span(0, 5)
      )
      diag.should be_a(Hecate::Core::Diagnostic)
      diag.message.should eq("test error")
    end

    it "supports diagnostic matchers" do
      diagnostics = [
        diagnostic(Hecate::Core::Diagnostic::Severity::Error, "test error", span(0, 5)),
      ]

      diagnostics.should have_error("test error")
      diagnostics.should_not have_warning
    end
  end
end
