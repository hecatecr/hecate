module Hecate::Core
  # Builder pattern for constructing diagnostics with fluent method chaining
  class DiagnosticBuilder
    # The diagnostic being built
    @diagnostic : Diagnostic

    def initialize(@diagnostic : Diagnostic)
    end

    # Add a primary label (main error location)
    def primary(span : Span, message : String = "") : self
      @diagnostic.labels << Diagnostic::Label.new(span, message, Diagnostic::Label::Style::Primary)
      self
    end

    # Add a secondary label (related location)
    def secondary(span : Span, message : String = "") : self
      @diagnostic.labels << Diagnostic::Label.new(span, message, Diagnostic::Label::Style::Secondary)
      self
    end

    # Set help text for the diagnostic
    def help(text : String) : self
      @diagnostic.help(text)
      self
    end

    # Add a note to the diagnostic
    def note(text : String) : self
      @diagnostic.note(text)
      self
    end

    # Build and return the configured diagnostic
    def build : Diagnostic
      @diagnostic
    end

    # Convenience method to access the diagnostic directly
    def to_diagnostic : Diagnostic
      @diagnostic
    end

    # Allow iteration over labels for advanced use cases
    def each_label(&block : Diagnostic::Label ->)
      @diagnostic.labels.each do |label|
        yield label
      end
    end

    # Check the current severity
    def severity : Diagnostic::Severity
      @diagnostic.severity
    end

    # Check the current message
    def message : String
      @diagnostic.message
    end

    # Count of labels added so far
    def label_count : Int32
      @diagnostic.labels.size
    end

    # Count of notes added so far
    def note_count : Int32
      @diagnostic.notes.size
    end

    # Check if help has been set
    def has_help? : Bool
      !@diagnostic.help.nil?
    end
  end

  # Module-level factory methods for creating DiagnosticBuilder instances
  
  # Create an error diagnostic builder
  def self.error(message : String) : DiagnosticBuilder
    DiagnosticBuilder.new(Diagnostic.new(Diagnostic::Severity::Error, message))
  end

  # Create a warning diagnostic builder
  def self.warning(message : String) : DiagnosticBuilder
    DiagnosticBuilder.new(Diagnostic.new(Diagnostic::Severity::Warning, message))
  end

  # Create an info diagnostic builder
  def self.info(message : String) : DiagnosticBuilder
    DiagnosticBuilder.new(Diagnostic.new(Diagnostic::Severity::Info, message))
  end

  # Create a hint diagnostic builder
  def self.hint(message : String) : DiagnosticBuilder
    DiagnosticBuilder.new(Diagnostic.new(Diagnostic::Severity::Hint, message))
  end

  # Create a diagnostic builder with custom severity
  def self.diagnostic(severity : Diagnostic::Severity, message : String) : DiagnosticBuilder
    DiagnosticBuilder.new(Diagnostic.new(severity, message))
  end
end