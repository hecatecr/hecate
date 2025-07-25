module Hecate::Core
  # Represents a diagnostic message (error, warning, info, hint)
  class Diagnostic
    # Severity levels for diagnostics
    enum Severity
      Error
      Warning
      Info
      Hint
    end

    # A label that points to a specific span in the source
    struct Label
      getter span : Span
      getter message : String
      getter style : Style

      enum Style
        Primary
        Secondary
      end

      def initialize(@span : Span, @message : String, @style : Style = Style::Primary)
      end
    end

    getter severity : Severity
    getter message : String
    getter labels : Array(Label)
    getter notes : Array(String)
    getter help : String?

    def initialize(@severity : Severity, @message : String)
      @labels = [] of Label
      @notes = [] of String
      @help = nil
    end

    # Add a primary label (main error location)
    def primary(span : Span, message : String = "") : self
      @labels << Label.new(span, message, Label::Style::Primary)
      self
    end

    # Add a secondary label (related location)
    def secondary(span : Span, message : String = "") : self
      @labels << Label.new(span, message, Label::Style::Secondary)
      self
    end

    # Add a help message
    def help(message : String) : self
      @help = message
      self
    end

    # Add a note
    def note(message : String) : self
      @notes << message
      self
    end

    # Check if this is an error
    def error? : Bool
      @severity == Severity::Error
    end

    # Check if this is a warning
    def warning? : Bool
      @severity == Severity::Warning
    end

    # Format the diagnostic for display
    def to_s(io : IO) : Nil
      io << severity.to_s.downcase << ": " << message

      if help_msg = @help
        io << "\nhelp: " << help_msg
      end

      @notes.each do |note|
        io << "\nnote: " << note
      end
    end

    # Pretty-print the diagnostic with source context
    def format(source_map : SourceMap, io : IO = STDOUT) : Nil
      # Header
      case @severity
      when Severity::Error
        io.print "\e[31;1merror\e[0m\e[1m: #{@message}\e[0m\n"
      when Severity::Warning
        io.print "\e[33;1mwarning\e[0m\e[1m: #{@message}\e[0m\n"
      when Severity::Info
        io.print "\e[36;1minfo\e[0m\e[1m: #{@message}\e[0m\n"
      when Severity::Hint
        io.print "\e[32;1mhint\e[0m\e[1m: #{@message}\e[0m\n"
      end

      # Labels with source context
      @labels.each do |label|
        format_label(label, source_map, io)
      end

      # Help and notes
      if help_msg = @help
        io.print "\e[36mhelp\e[0m: #{help_msg}\n"
      end

      @notes.each do |note|
        io.print "\e[36mnote\e[0m: #{note}\n"
      end
    end

    private def format_label(label : Label, source_map : SourceMap, io : IO) : Nil
      source = source_map.source_file(label.span.source_id)
      start_pos = source_map.byte_to_position(label.span.source_id, label.span.start_byte)
      end_pos = source_map.byte_to_position(label.span.source_id, label.span.end_byte - 1)

      # File location
      io.print "  \e[34m-->\e[0m #{source.name}:#{start_pos.display_line}:#{start_pos.display_column}\n"

      # Extract lines
      lines = source.content.lines
      line_range = (start_pos.line..end_pos.line)

      # Print lines with indicators
      line_range.each do |line_idx|
        next if line_idx >= lines.size

        line = lines[line_idx]
        line_num = line_idx + 1

        # Line number and content
        io.printf "   \e[34m%3d |\e[0m %s\n", line_num, line.chomp

        # Underline for this line
        if line_idx == start_pos.line && line_idx == end_pos.line
          # Single line
          start_col = start_pos.column
          end_col = end_pos.column
          print_underline(io, start_col, end_col - start_col + 1, label)
        elsif line_idx == start_pos.line
          # First line of multi-line span
          start_col = start_pos.column
          print_underline(io, start_col, line.size - start_col, label)
        elsif line_idx == end_pos.line
          # Last line of multi-line span
          print_underline(io, 0, end_pos.column + 1, label)
        else
          # Middle line of multi-line span
          print_underline(io, 0, line.size, label)
        end
      end
    end

    private def print_underline(io : IO, start_col : Int32, length : Int32, label : Label) : Nil
      io.print "       \e[34m|\e[0m "
      io.print " " * start_col

      case label.style
      when Label::Style::Primary
        io.print "\e[31;1m"
        io.print "^" * length
      when Label::Style::Secondary
        io.print "\e[33m"
        io.print "-" * length
      end

      if !label.message.empty?
        io.print " #{label.message}"
      end

      io.print "\e[0m\n"
    end
  end

  # Helper functions for creating diagnostics
  def self.error(message : String) : Diagnostic
    Diagnostic.new(Diagnostic::Severity::Error, message)
  end

  def self.warning(message : String) : Diagnostic
    Diagnostic.new(Diagnostic::Severity::Warning, message)
  end

  def self.info(message : String) : Diagnostic
    Diagnostic.new(Diagnostic::Severity::Info, message)
  end

  def self.hint(message : String) : Diagnostic
    Diagnostic.new(Diagnostic::Severity::Hint, message)
  end
end
