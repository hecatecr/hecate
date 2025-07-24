require "../../test_spec_helper"

describe Hecate::Core::DiagnosticBuilder do
  describe "#initialize" do
    it "wraps a diagnostic instance" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "test error")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      builder.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      builder.message.should eq("test error")
    end
  end

  describe "label builder methods" do
    it "adds primary labels" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "test error")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      test_span = span(10, 5)
      result = builder.primary(test_span, "primary label")
      
      # Should return self for chaining
      result.should be(builder)
      
      # Should add the label
      builder.label_count.should eq(1)
      
      # Verify label was added correctly
      built = builder.build
      built.labels.size.should eq(1)
      built.labels[0].span.should eq(test_span)
      built.labels[0].message.should eq("primary label")
      built.labels[0].style.should eq(Hecate::Core::Diagnostic::Label::Style::Primary)
    end

    it "adds secondary labels" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Warning, "test warning")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      test_span = span(20, 3)
      result = builder.secondary(test_span, "secondary label")
      
      # Should return self for chaining
      result.should be(builder)
      
      # Should add the label
      builder.label_count.should eq(1)
      
      # Verify label was added correctly
      built = builder.build
      built.labels.size.should eq(1)
      built.labels[0].span.should eq(test_span)
      built.labels[0].message.should eq("secondary label")
      built.labels[0].style.should eq(Hecate::Core::Diagnostic::Label::Style::Secondary)
    end

    it "supports multiple labels in order" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "multiple labels")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      span1 = span(10, 5)
      span2 = span(20, 3)
      span3 = span(30, 2)
      
      builder
        .primary(span1, "first label")
        .secondary(span2, "second label")
        .primary(span3, "third label")
      
      builder.label_count.should eq(3)
      
      built = builder.build
      built.labels.size.should eq(3)
      
      # Verify order is preserved
      built.labels[0].message.should eq("first label")
      built.labels[0].style.should eq(Hecate::Core::Diagnostic::Label::Style::Primary)
      
      built.labels[1].message.should eq("second label")
      built.labels[1].style.should eq(Hecate::Core::Diagnostic::Label::Style::Secondary)
      
      built.labels[2].message.should eq("third label")
      built.labels[2].style.should eq(Hecate::Core::Diagnostic::Label::Style::Primary)
    end

    it "handles empty label messages" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Info, "info message")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      test_span = span(5, 10)
      builder.primary(test_span)  # No message
      
      built = builder.build
      built.labels.size.should eq(1)
      built.labels[0].message.should eq("")
    end
  end

  describe "method chaining" do
    it "supports fluent chaining of label methods" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "chaining test")
      
      result = Hecate::Core::DiagnosticBuilder.new(diagnostic)
        .primary(span(10, 5), "primary")
        .secondary(span(20, 3), "secondary")
        .primary(span(30, 2), "another primary")
      
      result.should be_a(Hecate::Core::DiagnosticBuilder)
      result.label_count.should eq(3)
    end
  end

  describe "help and note builder methods" do
    it "sets help text" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "help test")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      result = builder.help("This is helpful advice")
      
      # Should return self for chaining
      result.should be(builder)
      
      # Should set the help
      builder.has_help?.should be_true
      
      built = builder.build
      built.help.should eq("This is helpful advice")
    end

    it "overwrites help text on multiple calls" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Warning, "multiple help")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      builder
        .help("First help")
        .help("Second help")
      
      built = builder.build
      built.help.should eq("Second help")
    end

    it "adds notes" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Info, "note test")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      result = builder.note("This is a note")
      
      # Should return self for chaining
      result.should be(builder)
      
      # Should add the note
      builder.note_count.should eq(1)
      
      built = builder.build
      built.notes.size.should eq(1)
      built.notes[0].should eq("This is a note")
    end

    it "accumulates multiple notes" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Hint, "multiple notes")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      builder
        .note("First note")
        .note("Second note")
        .note("Third note")
      
      builder.note_count.should eq(3)
      
      built = builder.build
      built.notes.size.should eq(3)
      built.notes[0].should eq("First note")
      built.notes[1].should eq("Second note")
      built.notes[2].should eq("Third note")
    end

    it "handles empty strings" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "empty test")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      builder
        .help("")
        .note("")
      
      built = builder.build
      built.help.should eq("")
      built.notes.size.should eq(1)
      built.notes[0].should eq("")
    end
  end

  describe "complete builder workflow" do
    it "supports chaining all methods together" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "complex diagnostic")
      
      result = Hecate::Core::DiagnosticBuilder.new(diagnostic)
        .primary(span(10, 5), "primary error location")
        .secondary(span(20, 3), "related location")
        .help("Try adding a semicolon")
        .note("This error is common in new code")
        .note("See the style guide for more info")
      
      result.should be_a(Hecate::Core::DiagnosticBuilder)
      result.label_count.should eq(2)
      result.note_count.should eq(2)
      result.has_help?.should be_true
      
      built = result.build
      built.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      built.message.should eq("complex diagnostic")
      built.labels.size.should eq(2)
      built.notes.size.should eq(2)
      built.help.should eq("Try adding a semicolon")
    end
  end

  describe "iteration support" do
    it "allows iteration over labels" do
      diagnostic = Hecate::Core::Diagnostic.new(Hecate::Core::Diagnostic::Severity::Error, "iteration test")
      builder = Hecate::Core::DiagnosticBuilder.new(diagnostic)
      
      builder
        .primary(span(10, 5), "first")
        .secondary(span(20, 3), "second")
      
      labels = [] of Hecate::Core::Diagnostic::Label
      builder.each_label do |label|
        labels << label
      end
      
      labels.size.should eq(2)
      labels[0].message.should eq("first")
      labels[1].message.should eq("second")
    end
  end

  describe "module-level factory methods" do
    it "creates error diagnostic builders" do
      builder = Hecate::Core.error("test error message")
      
      builder.should be_a(Hecate::Core::DiagnosticBuilder)
      builder.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      builder.message.should eq("test error message")
      
      diagnostic = builder.build
      diagnostic.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      diagnostic.message.should eq("test error message")
    end

    it "creates warning diagnostic builders" do
      builder = Hecate::Core.warning("test warning message")
      
      builder.should be_a(Hecate::Core::DiagnosticBuilder)
      builder.severity.should eq(Hecate::Core::Diagnostic::Severity::Warning)
      builder.message.should eq("test warning message")
    end

    it "creates info diagnostic builders" do
      builder = Hecate::Core.info("test info message")
      
      builder.should be_a(Hecate::Core::DiagnosticBuilder)
      builder.severity.should eq(Hecate::Core::Diagnostic::Severity::Info)
      builder.message.should eq("test info message")
    end

    it "creates hint diagnostic builders" do
      builder = Hecate::Core.hint("test hint message")
      
      builder.should be_a(Hecate::Core::DiagnosticBuilder)
      builder.severity.should eq(Hecate::Core::Diagnostic::Severity::Hint)
      builder.message.should eq("test hint message")
    end

    it "creates diagnostic builders with custom severity" do
      builder = Hecate::Core.diagnostic(Hecate::Core::Diagnostic::Severity::Warning, "custom severity")
      
      builder.should be_a(Hecate::Core::DiagnosticBuilder)
      builder.severity.should eq(Hecate::Core::Diagnostic::Severity::Warning)
      builder.message.should eq("custom severity")
    end

    it "supports method chaining with factory methods" do
      diagnostic = Hecate::Core.error("chained error")
        .primary(span(10, 5), "error here")
        .secondary(span(20, 3), "related to this")
        .help("Try this solution")
        .note("Additional context")
        .build
      
      diagnostic.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      diagnostic.message.should eq("chained error")
      diagnostic.labels.size.should eq(2)
      diagnostic.help.should eq("Try this solution")
      diagnostic.notes.size.should eq(1)
      diagnostic.notes[0].should eq("Additional context")
    end

    it "demonstrates fluent API usage" do
      # This test shows the intended usage pattern
      result = Hecate::Core.error("undefined variable 'x'")
        .primary(span(42, 1), "used here")
        .secondary(span(10, 5), "similar name 'y' defined here")
        .help("did you mean 'y'?")
        .note("variables must be defined before use")
        .build
      
      result.should be_a(Hecate::Core::Diagnostic)
      result.error?.should be_true
      result.labels.size.should eq(2)
      result.labels[0].style.should eq(Hecate::Core::Diagnostic::Label::Style::Primary)
      result.labels[1].style.should eq(Hecate::Core::Diagnostic::Label::Style::Secondary)
    end
  end
end