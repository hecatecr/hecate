module Hecate::Lex
  # Utility for printing diagnostics in a user-friendly format
  #
  # Provides both simple and detailed diagnostic output with
  # source context and color support.
  #
  # Example:
  # ```
  # printer = DiagnosticPrinter.new(source_file)
  # printer.print(diagnostics)
  # ```
  class DiagnosticPrinter
    # Source file for extracting context
    getter source_file : Hecate::Core::SourceFile
    
    # Whether to use color output
    getter use_color : Bool
    
    # Whether to show source context
    getter show_context : Bool
    
    # Number of context lines to show
    getter context_lines : Int32
    
    def initialize(@source_file : Hecate::Core::SourceFile, 
                   @use_color = true,
                   @show_context = true,
                   @context_lines = 2)
      # Respect NO_COLOR environment variable
      @use_color = false if ENV["NO_COLOR"]?
    end
    
    # Print all diagnostics
    def print(diagnostics : Array(Hecate::Core::Diagnostic), io : IO = STDOUT)
      return if diagnostics.empty?
      
      diagnostics.each_with_index do |diagnostic, index|
        print_diagnostic(diagnostic, io)
        io.puts unless index == diagnostics.size - 1  # Add blank line between diagnostics
      end
    end
    
    # Print a single diagnostic
    def print_diagnostic(diagnostic : Hecate::Core::Diagnostic, io : IO = STDOUT)
      # Print severity and message
      severity_str = format_severity(diagnostic.severity)
      io.print severity_str
      io.print ": "
      io.puts diagnostic.message
      
      # Print labels with source context
      diagnostic.labels.each do |label|
        print_label(label, io)
      end
      
      # Print help text if available
      if help = diagnostic.help
        io.print "  "
        io.print color_text("help", :cyan) if @use_color
        io.print ": "
        io.puts help
      end
      
      # Print notes
      diagnostic.notes.each do |note|
        io.print "  "
        io.print color_text("note", :blue) if @use_color
        io.print ": "
        io.puts note
      end
    end
    
    # Print a simple format suitable for examples
    def print_simple(diagnostics : Array(Hecate::Core::Diagnostic), io : IO = STDOUT)
      diagnostics.each do |diagnostic|
        io.print "#{diagnostic.severity}: #{diagnostic.message}"
        
        if diagnostic.labels.any?
          label = diagnostic.labels.first
          pos = @source_file.byte_to_position(label.span.start_byte)
          io.print " at line #{pos.display_line}, column #{pos.display_column}"
        end
        
        io.puts
        
        if help = diagnostic.help
          io.puts "  help: #{help}"
        end
      end
    end
    
    private def print_label(label : Hecate::Core::Diagnostic::Label, io : IO)
      pos = @source_file.byte_to_position(label.span.start_byte)
      end_pos = @source_file.byte_to_position(label.span.end_byte)
      
      # Print location
      io.print "  --> "
      io.print "#{@source_file.path}:#{pos.display_line}:#{pos.display_column}"
      io.puts
      
      if @show_context
        # Show source context
        line_num = pos.line
        
        # Ensure we don't go out of bounds
        total_lines = @source_file.line_offsets.size
        
        # Show context lines before
        start_line = [0, line_num - @context_lines].max
        (start_line...line_num).each do |i|
          break if i >= total_lines
          print_source_line(i, io, highlight: false)
        end
        
        # Show the error line with highlighting
        if line_num < total_lines
          print_source_line(line_num, io, highlight: true, label: label)
        end
        
        # Show context lines after
        end_line = [line_num + @context_lines, total_lines - 1].min
        ((line_num + 1)..end_line).each do |i|
          break if i >= total_lines
          print_source_line(i, io, highlight: false)
        end
      end
    end
    
    private def print_source_line(line_num : Int32, io : IO, highlight : Bool, label : Hecate::Core::Diagnostic::Label? = nil)
      line_text = @source_file.line_at(line_num)
      return unless line_text
      
      # Print line number
      line_str = (line_num + 1).to_s
      io.print " #{line_str.rjust(4)} | "
      
      # Print the line
      io.print line_text
      io.puts
      
      # Print highlighting if requested
      if highlight && label
        pos = @source_file.byte_to_position(label.span.start_byte)
        end_pos = @source_file.byte_to_position(label.span.end_byte)
        
        if pos.line == line_num
          # Print pointer line
          io.print "      | "
          io.print " " * pos.column
          
          # Calculate highlight length
          if end_pos.line == line_num
            length = end_pos.column - pos.column
          else
            # Multi-line span, highlight to end of line
            length = line_text.size - pos.column
          end
          
          length = 1 if length < 1
          
          # Print the highlight
          if label.style.primary?
            io.print color_text("^" * length, :red) if @use_color
            io.print "^" * length unless @use_color
          else
            io.print color_text("-" * length, :yellow) if @use_color
            io.print "-" * length unless @use_color
          end
          
          # Print label message
          if label.message && !label.message.empty?
            io.print " "
            io.print label.message
          end
          
          io.puts
        end
      end
    end
    
    private def format_severity(severity : Hecate::Core::Diagnostic::Severity) : String
      text = severity.to_s.downcase
      
      return text unless @use_color
      
      case severity
      when .error?
        color_text(text, :red)
      when .warning?
        color_text(text, :yellow)
      when .info?
        color_text(text, :blue)
      when .hint?
        color_text(text, :green)
      else
        text
      end
    end
    
    private def color_text(text : String, color : Symbol) : String
      case color
      when :red
        "\e[31m#{text}\e[0m"
      when :yellow
        "\e[33m#{text}\e[0m"
      when :blue
        "\e[34m#{text}\e[0m"
      when :green
        "\e[32m#{text}\e[0m"
      when :cyan
        "\e[36m#{text}\e[0m"
      else
        text
      end
    end
  end
end