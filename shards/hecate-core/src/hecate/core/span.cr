module Hecate::Core
  # Represents a range of bytes in a source file
  struct Span
    getter source_id : UInt32
    getter start_byte : Int32
    getter end_byte : Int32
    
    def initialize(@source_id : UInt32, @start_byte : Int32, @end_byte : Int32)
      raise ArgumentError.new("Invalid span: end_byte (#{@end_byte}) cannot be less than start_byte (#{@start_byte})") if @end_byte < @start_byte
    end
    
    # Calculate the byte length of this span
    def length : Int32
      @end_byte - @start_byte
    end

    def to_s(io)
      io << "Span(source=#{@source_id}, #{@start_byte}..#{@end_byte})"
    end

    def ==(other : Span)
      @source_id == other.source_id &&
        @start_byte == other.start_byte &&
        @end_byte == other.end_byte
    end

    # Check if this span contains a byte offset
    def contains?(byte_offset : Int32) : Bool
      byte_offset >= @start_byte && byte_offset < @end_byte
    end

    # Check if this span overlaps with another span
    def overlaps?(other : Span) : Bool
      return false if @source_id != other.source_id
      @start_byte < other.end_byte && other.start_byte < @end_byte
    end

    # Create a new span that encompasses both spans
    def merge(other : Span) : Span
      raise ArgumentError.new("Cannot merge spans from different sources") if @source_id != other.source_id
      
      new_start = Math.min(@start_byte, other.start_byte)
      new_end = Math.max(@end_byte, other.end_byte)
      
      Span.new(@source_id, new_start, new_end)
    end
  end
end