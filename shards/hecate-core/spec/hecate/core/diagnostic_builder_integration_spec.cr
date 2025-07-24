require "../../test_spec_helper"

describe "DiagnosticBuilder Integration Tests" do
  describe "complex diagnostic construction" do
    it "builds complex multi-span error with help and notes" do
      # Simulate a typical compiler error scenario
      source = create_test_source(<<-CODE)
        func fibonacci(n) {
          if n <= 1 {
            return x  // undefined variable
          }
          return fibonacci(n - 1) + fibonacci(n - 2)
        }
      CODE
      
      # Build a comprehensive diagnostic using the fluent API
      diagnostic = Hecate::Core.error("undefined variable 'x'")
        .primary(span(45, 1), "undefined variable used here")
        .secondary(span(17, 1), "parameter 'n' defined here")
        .secondary(span(0, 4), "function scope starts here")
        .help("did you mean to use 'n' instead of 'x'?")
        .note("all variables must be defined before use")
        .note("consider adding a variable declaration")
        .build
      
      # Verify the complete diagnostic structure
      diagnostic.severity.should eq(Hecate::Core::Diagnostic::Severity::Error)
      diagnostic.message.should eq("undefined variable 'x'")
      
      # Verify labels
      diagnostic.labels.size.should eq(3)
      diagnostic.labels[0].message.should eq("undefined variable used here")
      diagnostic.labels[0].style.should eq(Hecate::Core::Diagnostic::Label::Style::Primary)
      diagnostic.labels[1].style.should eq(Hecate::Core::Diagnostic::Label::Style::Secondary)
      diagnostic.labels[2].style.should eq(Hecate::Core::Diagnostic::Label::Style::Secondary)
      
      # Verify help and notes
      diagnostic.help.should eq("did you mean to use 'n' instead of 'x'?")
      diagnostic.notes.size.should eq(2)
      diagnostic.notes[0].should eq("all variables must be defined before use")
      diagnostic.notes[1].should eq("consider adding a variable declaration")
    end

    it "builds syntax error with detailed context" do
      diagnostic = Hecate::Core.error("unexpected token ';'")
        .primary(span(25, 1), "unexpected semicolon")
        .secondary(span(20, 4), "statement starts here")
        .help("remove the extra semicolon")
        .note("semicolons are not required after block statements")
        .build
      
      diagnostic.error?.should be_true
      diagnostic.labels.size.should eq(2)
      diagnostic.help.should_not be_nil
      diagnostic.notes.size.should eq(1)
    end

    it "builds warning with suggestions" do
      diagnostic = Hecate::Core.warning("unused variable 'temp'")
        .primary(span(10, 4), "variable defined but never used")
        .help("remove the variable or prefix with '_' to suppress this warning")
        .note("unused variables may indicate dead code")
        .build
      
      diagnostic.warning?.should be_true
      diagnostic.labels.size.should eq(1)
      diagnostic.labels[0].style.should eq(Hecate::Core::Diagnostic::Label::Style::Primary)
    end
  end

  describe "edge case handling" do
    it "builds minimal diagnostic with no labels or help" do
      diagnostic = Hecate::Core.info("compilation complete").build
      
      diagnostic.severity.should eq(Hecate::Core::Diagnostic::Severity::Info)
      diagnostic.message.should eq("compilation complete")
      diagnostic.labels.should be_empty
      diagnostic.help.should be_nil
      diagnostic.notes.should be_empty
    end

    it "handles empty messages and labels" do
      diagnostic = Hecate::Core.hint("")
        .primary(span(0, 0), "")
        .help("")
        .note("")
        .build
      
      diagnostic.message.should eq("")
      diagnostic.labels.size.should eq(1)
      diagnostic.labels[0].message.should eq("")
      diagnostic.help.should eq("")
      diagnostic.notes.size.should eq(1)
      diagnostic.notes[0].should eq("")
    end

    it "handles multiple build calls on same builder" do
      builder = Hecate::Core.error("test error")
        .primary(span(10, 5), "location")
      
      first_build = builder.build
      second_build = builder.build
      
      # Both should be the same diagnostic instance
      first_build.should be(second_build)
      first_build.message.should eq("test error")
      second_build.labels.size.should eq(1)
    end

    it "allows modification after first build" do
      builder = Hecate::Core.warning("initial warning")
        .primary(span(10, 5), "first location")
      
      first_diagnostic = builder.build
      first_diagnostic.labels.size.should eq(1)
      
      # Add more to the builder
      builder.secondary(span(20, 3), "second location")
        .help("additional help")
      
      second_diagnostic = builder.build
      second_diagnostic.labels.size.should eq(2)
      second_diagnostic.help.should eq("additional help")
      
      # Should be the same instance, modified
      first_diagnostic.should be(second_diagnostic)
    end
  end

  describe "real-world usage patterns" do
    it "simulates lexer error reporting" do
      # Simulate finding an invalid character in source
      diagnostic = Hecate::Core.error("invalid character '@'")
        .primary(span(42, 1), "invalid character found here")
        .help("remove or replace the invalid character")
        .note("only letters, digits, and underscore are allowed in identifiers")
        .build
      
      diagnostic.error?.should be_true
      diagnostic.message.should contain("invalid character")
    end

    it "simulates parser error reporting" do
      # Simulate a missing closing brace
      diagnostic = Hecate::Core.error("expected '}' but found end of file")
        .primary(span(150, 0), "reached end of file here")
        .secondary(span(42, 1), "unmatched '{' opened here")
        .help("add a closing '}' to match the opening brace")
        .note("all opening braces must have corresponding closing braces")
        .build
      
      diagnostic.labels.size.should eq(2)
      diagnostic.labels[1].style.should eq(Hecate::Core::Diagnostic::Label::Style::Secondary)
    end

    it "simulates semantic analyzer warning" do
      # Simulate type mismatch warning
      diagnostic = Hecate::Core.warning("implicit conversion from 'Int32' to 'String'")
        .primary(span(75, 8), "conversion happens here")
        .secondary(span(42, 5), "expected String type declared here")
        .help("use explicit conversion with .to_s")
        .note("implicit conversions may cause unexpected behavior")
        .build
      
      diagnostic.warning?.should be_true
      diagnostic.message.should contain("implicit conversion")
    end
  end

  describe "builder immutability and state" do
    it "preserves diagnostic state through chaining" do
      builder = Hecate::Core.error("state test")
      
      # Each call should return the same builder instance
      same_builder = builder
        .primary(span(10, 5), "first")
        .secondary(span(20, 3), "second")
        .help("help text")
        .note("first note")
        .note("second note")
      
      builder.should be(same_builder)
      builder.label_count.should eq(2)
      builder.note_count.should eq(2)
      builder.has_help?.should be_true
    end

    it "provides accurate state queries during building" do
      builder = Hecate::Core.hint("state queries")
      
      # Initially empty
      builder.label_count.should eq(0)
      builder.note_count.should eq(0)
      builder.has_help?.should be_false
      
      # After adding primary label
      builder.primary(span(10, 5), "label")
      builder.label_count.should eq(1)
      builder.note_count.should eq(0)
      builder.has_help?.should be_false
      
      # After adding help
      builder.help("help text")
      builder.label_count.should eq(1)
      builder.note_count.should eq(0)
      builder.has_help?.should be_true
      
      # After adding notes
      builder.note("note 1").note("note 2")
      builder.label_count.should eq(1)
      builder.note_count.should eq(2)
      builder.has_help?.should be_true
    end
  end

  describe "compatibility with existing diagnostic methods" do
    it "produces diagnostics compatible with existing helper methods" do
      diagnostic = Hecate::Core.error("compatibility test")
        .primary(span(10, 5), "error location")
        .help("fix suggestion")
        .build
      
      # Should work with existing diagnostic methods
      diagnostic.error?.should be_true
      diagnostic.warning?.should be_false
      
      # Should work with test matchers
      [diagnostic].should have_error("compatibility test")
      [diagnostic].should have_error(span: span(10, 5))
    end

    it "can be used in diagnostic collections" do
      diagnostics = [
        Hecate::Core.error("first error").primary(span(10, 5), "here").build,
        Hecate::Core.warning("first warning").primary(span(20, 3), "there").build,
        Hecate::Core.info("info message").build
      ]
      
      diagnostics.size.should eq(3)
      diagnostics[0].error?.should be_true
      diagnostics[1].warning?.should be_true
      diagnostics[2].severity.should eq(Hecate::Core::Diagnostic::Severity::Info)
      
      # Should work with test matchers
      diagnostics.should have_error
      diagnostics.should have_warning
      diagnostics.should have_info
    end
  end
end