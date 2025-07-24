module Hecate::Core
  # Monochrome TTY renderer for diagnostic output with proper formatting and alignment
  class TTYRenderer
    @no_color : Bool
    
    def initialize(@output : IO = STDOUT, @width : Int32 = 80)
      @no_color = ENV["NO_COLOR"]? != nil
    end
    
    def emit(diagnostic : Diagnostic, source_map : SourceMap)
      emit_header(diagnostic)
      
      # Group labels by source file
      labels_by_source = diagnostic.labels.group_by(&.span.source_id)
      
      labels_by_source.each do |source_id, labels|
        source = source_map.get(source_id)
        next unless source
        
        emit_source_section(source, labels, source_map)
      end
      
      emit_help(diagnostic.help) if diagnostic.help
      diagnostic.notes.each { |note| emit_note(note) }
    end
    
    # Overload to accept DiagnosticBuilder
    def emit(diagnostic_builder : DiagnosticBuilder, source_map : SourceMap)
      emit(diagnostic_builder.build, source_map)
    end
    
    private def emit_header(diagnostic)
      severity_text = case diagnostic.severity
      when .error? then "error"
      when .warning? then "warning"
      when Diagnostic::Severity::Info then "info"
      when Diagnostic::Severity::Hint then "hint"
      end
      
      @output.puts "#{severity_text}: #{diagnostic.message}"
    end
    
    private def emit_source_section(source : SourceFile, labels : Array(Diagnostic::Label), source_map : SourceMap)
      # Extract and sort label positions
      label_positions = extract_and_sort_label_positions(labels, source)
      return if label_positions.empty?
      
      # Calculate context line range
      lines_to_show = calculate_context_lines(label_positions, source)
      
      # Calculate line number width for proper alignment
      line_num_width = (lines_to_show.end + 1).to_s.size
      
      # Show file location header
      emit_file_location_header(label_positions.first, source, line_num_width)
      
      # Render each line in the display range
      lines_to_show.each do |line_num|
        line_content = source.line_at(line_num)
        next unless line_content
        
        # Find labels that apply to this line
        line_labels = get_labels_for_line(label_positions, line_num)
        
        # Format and display the line
        format_and_display_line(line_num, line_content, line_labels, line_num_width)
      end
      
      emit_section_footer(line_num_width)
    end
    
    # Extract and sort label positions for rendering
    private def extract_and_sort_label_positions(labels : Array(Diagnostic::Label), source : SourceFile)
      label_positions = labels.compact_map do |label|
        start_pos = source.byte_to_position(label.span.start_byte)
        end_pos = source.byte_to_position(label.span.end_byte - 1)
        {label, start_pos, end_pos}
      end
      
      # Sort by start position (line first, then column)
      label_positions.sort_by { |_, start_pos, _| {start_pos.line, start_pos.column} }
    end
    
    # Calculate which lines to display with context
    private def calculate_context_lines(label_positions, source : SourceFile) : Range(Int32, Int32)
      return (0..0) if label_positions.empty?
      
      # Find the range of lines covered by all labels
      min_line = label_positions.map { |_, start_pos, _| start_pos.line }.min
      max_line = label_positions.map { |_, _, end_pos| end_pos.line }.max
      
      # Add context lines before and after
      context_lines = 2
      display_start = Math.max(0, min_line - context_lines)
      display_end = Math.min(source.line_offsets.size - 1, max_line + context_lines)
      
      (display_start..display_end)
    end
    
    # Check if a label affects a specific line
    private def label_on_line?(label_data, line_num : Int32) : Bool
      _, start_pos, end_pos = label_data
      line_num >= start_pos.line && line_num <= end_pos.line
    end
    
    # Get all labels that affect a specific line
    private def get_labels_for_line(label_positions, line_num : Int32)
      label_positions.select { |label_data| label_on_line?(label_data, line_num) }
    end
    
    # Emit the file location header
    private def emit_file_location_header(first_label_pos, source : SourceFile, line_num_width : Int32)
      _, start_pos, _ = first_label_pos
      @output.puts "  --> #{source.path}:#{start_pos.display_line}:#{start_pos.display_column}"
      @output.puts "#{" " * line_num_width} |"
    end
    
    # Format and display a single line with its labels
    private def format_and_display_line(line_num : Int32, line_content : String, line_labels, line_num_width : Int32)
      line_display_num = line_num + 1
      formatted_line_num = format_line_number(line_display_num, line_num_width)
      
      # Always display the line
      @output.puts "#{formatted_line_num} | #{line_content}"
      
      # Emit underlines if there are labels on this line
      unless line_labels.empty?
        emit_label_underlines(line_content, line_labels, line_num, line_num_width)
      end
    end
    
    # Emit footer separator
    private def emit_section_footer(line_num_width : Int32)
      @output.puts "#{" " * line_num_width} |"
    end
    
    private def format_line_number(line_num : Int32, width : Int32) : String
      line_num.to_s.rjust(width)
    end
    
    private def emit_label_underlines(line : String, label_positions : Array, line_num : Int32, line_num_width : Int32)
      # Sort labels by start position to handle overlapping properly
      sorted_labels = label_positions.sort_by { |_, start_pos, _| start_pos.column }
      
      # Track underlines to handle vertical spacing for overlapping labels
      underlines = [] of {String, String}  # {underline_chars, message}
      
      # Create underline for each label
      sorted_labels.each do |label, start_pos, end_pos|
        # Calculate start and end columns for this line
        start_col, end_col = calculate_label_columns(start_pos, end_pos, line_num, line)
        
        # Skip if no valid range
        next if start_col < 0 || start_col > end_col
        
        # Choose underline character based on label style
        underline_char = get_underline_character(label.style)
        
        # Create the underline string with proper spacing
        underline_chars = create_underline_chars(start_col, end_col, underline_char)
        
        # Store underline with its message
        message = label.message.empty? ? "" : " #{label.message}"
        underlines << {underline_chars, message}
      end
      
      # Emit all underlines with proper formatting
      emit_formatted_underlines(underlines, line_num_width)
    end
    
    # Calculate start and end columns for a label on a specific line
    private def calculate_label_columns(start_pos : Position, end_pos : Position, line_num : Int32, line : String) : {Int32, Int32}
      start_col = line_num == start_pos.line ? start_pos.column : 0
      end_col = if line_num == end_pos.line
                  Math.min(end_pos.column, line.size - 1)
                else
                  line.size - 1
                end
      
      # Ensure we don't go beyond the line length
      start_col = Math.max(0, Math.min(start_col, line.size - 1))
      end_col = Math.max(start_col, Math.min(end_col, line.size - 1))
      
      {start_col, end_col}
    end
    
    # Get the appropriate underline character for a label style
    private def get_underline_character(style : Diagnostic::Label::Style) : String
      case style
      when Diagnostic::Label::Style::Primary then "^"
      when Diagnostic::Label::Style::Secondary then "~"
      else "^"  # Default fallback
      end
    end
    
    # Create underline characters with proper spacing
    private def create_underline_chars(start_col : Int32, end_col : Int32, char : String) : String
      spaces = " " * start_col
      underline_length = end_col - start_col + 1
      underlines = char * underline_length
      spaces + underlines
    end
    
    # Emit all underlines with proper formatting and spacing
    private def emit_formatted_underlines(underlines : Array({String, String}), line_num_width : Int32)
      underline_prefix = " " * line_num_width + " | "
      
      underlines.each do |underline_chars, message|
        @output.puts underline_prefix + underline_chars + message
      end
    end
    
    private def emit_help(help : String?)
      return unless help
      @output.puts "help: #{help}"
    end
    
    private def emit_note(note : String)
      @output.puts "note: #{note}"
    end
  end
end