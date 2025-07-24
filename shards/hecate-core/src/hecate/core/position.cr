module Hecate::Core
  # Represents a position in a source file as line and column numbers (zero-based internally)
  struct Position
    getter line : Int32    # 0-based internally
    getter column : Int32  # 0-based internally

    def initialize(@line : Int32, @column : Int32)
    end

    # Convert to 1-based line number for display
    def display_line : Int32
      @line + 1
    end

    # Convert to 1-based column number for display
    def display_column : Int32
      @column + 1
    end

    def to_s(io)
      io << "#{display_line}:#{display_column}"
    end

    def ==(other : Position)
      @line == other.line && @column == other.column
    end

    def <=>(other : Position)
      cmp = @line <=> other.line
      cmp == 0 ? @column <=> other.column : cmp
    end
  end
end