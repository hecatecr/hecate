module Hecate::Core
  struct SourceFile
    getter id : UInt32
    getter path : String
    getter contents : String
    getter line_offsets : Array(Int32)
    
    def initialize(@id : UInt32, @path : String, @contents : String)
      @line_offsets = compute_line_offsets(@contents)
    end
    
    # Convert a byte offset to a Position (line and column)
    def byte_to_position(byte_offset : Int32) : Position
      # Handle edge cases
      return Position.new(0, 0) if byte_offset <= 0 || line_offsets.empty?
      
      # If beyond file, return position at end of last line
      if byte_offset >= contents.bytesize
        last_line = line_offsets.size - 1
        last_line_start = line_offsets[last_line]
        last_line_length = contents.bytesize - last_line_start
        return Position.new(last_line, last_line_length)
      end
      
      # Binary search to find the line containing this byte offset
      left = 0
      right = line_offsets.size - 1
      
      while left < right
        mid = left + (right - left + 1) // 2
        if line_offsets[mid] <= byte_offset
          left = mid
        else
          right = mid - 1
        end
      end
      
      line = left
      line_start = line_offsets[line]
      column = byte_offset - line_start
      
      Position.new(line, column)
    end
    
    # Convert a Position to a byte offset
    def position_to_byte(position : Position) : Int32?
      # Validate line number
      return nil if position.line < 0 || position.line >= line_offsets.size
      
      # Get the start of the requested line
      line_start = line_offsets[position.line]
      
      # Calculate the byte offset
      byte_offset = line_start + position.column
      
      # Validate the byte offset doesn't exceed the line length
      # For the last line, check against file size
      if position.line == line_offsets.size - 1
        return nil if byte_offset > contents.bytesize
      else
        # For other lines, check against the start of the next line
        next_line_start = line_offsets[position.line + 1]
        return nil if byte_offset >= next_line_start
      end
      
      byte_offset
    end
    
    # Extract a specific line from the source file
    def line_at(line_number : Int32) : String?
      # Validate line number
      return nil if line_number < 0 || line_number >= line_offsets.size
      
      # Get line boundaries
      line_start = line_offsets[line_number]
      
      # For the last line or if there's no next line
      if line_number == line_offsets.size - 1
        line_text = contents[line_start..]
      else
        line_end = line_offsets[line_number + 1] - 1  # Exclude the newline
        
        # Also exclude \r if it's a CRLF ending
        if line_end > line_start && contents[line_end - 1] == '\r'
          line_end -= 1
        end
        
        line_text = contents[line_start...line_end]
      end
      
      # Remove any remaining line ending characters
      line_text.chomp
    end
    
    # Extract a range of lines from the source file
    def line_range(start_line : Int32, end_line : Int32) : Array(String)
      lines = [] of String
      
      # Ensure valid range
      start_line = 0 if start_line < 0
      end_line = line_offsets.size - 1 if end_line >= line_offsets.size
      
      return lines if start_line > end_line
      
      (start_line..end_line).each do |line_num|
        if line = line_at(line_num)
          lines << line
        end
      end
      
      lines
    end
    
    private def compute_line_offsets(text : String) : Array(Int32)
      offsets = [0]
      byte_index = 0
      
      text.each_byte do |byte|
        byte_index += 1
        
        if byte == '\n'.ord
          offsets << byte_index
        elsif byte == '\r'.ord
          # Check if it's followed by \n (CRLF)
          if byte_index < text.bytesize && text.byte_at?(byte_index) == '\n'.ord
            byte_index += 1  # Skip the \n, we'll handle it as part of CRLF
          end
          offsets << byte_index
        end
      end
      
      offsets
    end
  end
end