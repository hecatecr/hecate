require "../../spec_helper"

describe Hecate::Core::SourceFile do
  describe "#initialize" do
    it "stores basic properties" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello world")
      source.id.should eq(1_u32)
      source.path.should eq("test.cr")
      source.contents.should eq("hello world")
    end
  end

  describe "#compute_line_offsets" do
    it "handles empty string" do
      source = Hecate::Core::SourceFile.new(1_u32, "empty.cr", "")
      source.line_offsets.should eq([0])
    end

    it "handles single line without newline" do
      source = Hecate::Core::SourceFile.new(1_u32, "single.cr", "hello world")
      source.line_offsets.should eq([0])
    end

    it "handles single line with newline" do
      source = Hecate::Core::SourceFile.new(1_u32, "single.cr", "hello world\n")
      source.line_offsets.should eq([0, 12])
    end

    it "handles multiple lines" do
      content = "line 1\nline 2\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "multi.cr", content)
      source.line_offsets.should eq([0, 7, 14])
    end

    it "handles multiple lines with trailing newline" do
      content = "line 1\nline 2\nline 3\n"
      source = Hecate::Core::SourceFile.new(1_u32, "multi.cr", content)
      source.line_offsets.should eq([0, 7, 14, 21])
    end

    it "always starts with 0" do
      ["", "x", "x\n", "\n", "\n\n"].each do |content|
        source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)
        source.line_offsets.first.should eq(0)
      end
    end
  end

  describe "#byte_to_position" do
    it "handles start of file" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello")
      pos = source.byte_to_position(0)
      pos.line.should eq(0)
      pos.column.should eq(0)
    end

    it "handles negative offsets" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello")
      pos = source.byte_to_position(-5)
      pos.line.should eq(0)
      pos.column.should eq(0)
    end

    it "handles middle of single line" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello world")
      pos = source.byte_to_position(6)
      pos.line.should eq(0)
      pos.column.should eq(6)
    end

    it "handles exact newline position" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello\nworld")
      pos = source.byte_to_position(5) # Position of '\n'
      pos.line.should eq(0)
      pos.column.should eq(5)
    end

    it "handles start of second line" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello\nworld")
      pos = source.byte_to_position(6) # Start of "world"
      pos.line.should eq(1)
      pos.column.should eq(0)
    end

    it "handles multiple lines" do
      content = "line 1\nline 2\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      # Middle of first line
      pos = source.byte_to_position(3)
      pos.line.should eq(0)
      pos.column.should eq(3)

      # Start of second line
      pos = source.byte_to_position(7)
      pos.line.should eq(1)
      pos.column.should eq(0)

      # Middle of third line
      pos = source.byte_to_position(17)
      pos.line.should eq(2)
      pos.column.should eq(3)
    end

    it "handles offset beyond file length" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello")
      pos = source.byte_to_position(100)
      pos.line.should eq(0)
      pos.column.should eq(5) # End of "hello"
    end

    it "handles empty file" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "")
      pos = source.byte_to_position(0)
      pos.line.should eq(0)
      pos.column.should eq(0)
    end

    it "handles file with only newlines" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "\n\n\n")

      pos = source.byte_to_position(0)
      pos.line.should eq(0)
      pos.column.should eq(0)

      pos = source.byte_to_position(1)
      pos.line.should eq(1)
      pos.column.should eq(0)

      pos = source.byte_to_position(2)
      pos.line.should eq(2)
      pos.column.should eq(0)
    end
  end

  describe "#position_to_byte" do
    it "converts valid positions at start of line" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello\nworld\n")

      source.position_to_byte(Hecate::Core::Position.new(0, 0)).should eq(0)
      source.position_to_byte(Hecate::Core::Position.new(1, 0)).should eq(6)
      source.position_to_byte(Hecate::Core::Position.new(2, 0)).should eq(12)
    end

    it "converts valid positions in middle of line" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello\nworld")

      source.position_to_byte(Hecate::Core::Position.new(0, 3)).should eq(3)
      source.position_to_byte(Hecate::Core::Position.new(1, 3)).should eq(9)
    end

    it "converts valid positions at end of line" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello\nworld")

      source.position_to_byte(Hecate::Core::Position.new(0, 5)).should eq(5)  # Position of '\n'
      source.position_to_byte(Hecate::Core::Position.new(1, 5)).should eq(11) # End of "world"
    end

    it "returns nil for out-of-bounds line" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello")

      source.position_to_byte(Hecate::Core::Position.new(-1, 0)).should be_nil
      source.position_to_byte(Hecate::Core::Position.new(1, 0)).should be_nil
    end

    it "returns nil for column exceeding line length" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello\nworld")

      # First line has 5 chars + newline
      source.position_to_byte(Hecate::Core::Position.new(0, 6)).should be_nil

      # Second line has 5 chars
      source.position_to_byte(Hecate::Core::Position.new(1, 6)).should be_nil
    end

    it "handles empty file" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "")

      source.position_to_byte(Hecate::Core::Position.new(0, 0)).should eq(0)
      source.position_to_byte(Hecate::Core::Position.new(0, 1)).should be_nil
    end

    it "round-trips with byte_to_position" do
      content = "line 1\nline 2\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      # Test various byte offsets
      [0, 3, 6, 7, 10, 14, 17, 20].each do |byte_offset|
        pos = source.byte_to_position(byte_offset)
        source.position_to_byte(pos).should eq(byte_offset)
      end
    end
  end

  describe "#line_at" do
    it "extracts lines from multi-line file" do
      content = "line 1\nline 2\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_at(0).should eq("line 1")
      source.line_at(1).should eq("line 2")
      source.line_at(2).should eq("line 3")
    end

    it "handles file with trailing newline" do
      content = "line 1\nline 2\n"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_at(0).should eq("line 1")
      source.line_at(1).should eq("line 2")
      source.line_at(2).should eq("") # Empty line after final newline
    end

    it "returns nil for out-of-bounds line numbers" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello")

      source.line_at(-1).should be_nil
      source.line_at(1).should be_nil
    end

    it "handles empty lines correctly" do
      content = "line 1\n\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_at(0).should eq("line 1")
      source.line_at(1).should eq("")
      source.line_at(2).should eq("line 3")
    end

    it "handles single line file without newline" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "hello world")
      source.line_at(0).should eq("hello world")
    end

    it "handles empty file" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "")
      source.line_at(0).should eq("")
    end
  end

  describe "#line_range" do
    it "extracts multiple consecutive lines" do
      content = "line 1\nline 2\nline 3\nline 4"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_range(1, 2).should eq(["line 2", "line 3"])
      source.line_range(0, 3).should eq(["line 1", "line 2", "line 3", "line 4"])
    end

    it "handles single line range" do
      content = "line 1\nline 2\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_range(1, 1).should eq(["line 2"])
    end

    it "clamps out-of-bounds ranges" do
      content = "line 1\nline 2\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_range(-1, 1).should eq(["line 1", "line 2"])
      source.line_range(1, 10).should eq(["line 2", "line 3"])
    end

    it "returns empty array for invalid range" do
      content = "line 1\nline 2"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_range(2, 1).should eq([] of String)
    end

    it "handles empty file" do
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", "")
      source.line_range(0, 0).should eq([""])
    end
  end

  describe "CRLF line ending handling" do
    it "handles pure CRLF line endings in compute_line_offsets" do
      content = "line 1\r\nline 2\r\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      # Offsets should point to the character after \r\n
      source.line_offsets.should eq([0, 8, 16])
    end

    it "handles mixed LF and CRLF endings" do
      content = "line 1\nline 2\r\nline 3\rline 4"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_offsets.should eq([0, 7, 15, 22])
    end

    it "handles lone CR as line ending" do
      content = "line 1\rline 2\rline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_offsets.should eq([0, 7, 14])
    end

    it "correctly calculates positions with CRLF" do
      content = "hello\r\nworld\r\n"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      # Start of "world"
      pos = source.byte_to_position(7)
      pos.line.should eq(1)
      pos.column.should eq(0)

      # Middle of "world"
      pos = source.byte_to_position(10)
      pos.line.should eq(1)
      pos.column.should eq(3)
    end

    it "extracts lines correctly with CRLF" do
      content = "line 1\r\nline 2\r\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_at(0).should eq("line 1")
      source.line_at(1).should eq("line 2")
      source.line_at(2).should eq("line 3")
    end

    it "handles CRLF at end of file" do
      content = "hello\r\n"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      source.line_at(0).should eq("hello")
      source.line_at(1).should eq("")
    end

    it "position_to_byte works with CRLF" do
      content = "hello\r\nworld"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      # Position at start of "world"
      source.position_to_byte(Hecate::Core::Position.new(1, 0)).should eq(7)

      # Position in middle of "world"
      source.position_to_byte(Hecate::Core::Position.new(1, 3)).should eq(10)
    end

    it "round-trips correctly with CRLF" do
      content = "line 1\r\nline 2\r\nline 3"
      source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

      # Test various positions
      [0, 3, 7, 8, 11, 16, 19].each do |byte_offset|
        pos = source.byte_to_position(byte_offset)
        result = source.position_to_byte(pos)
        result.should eq(byte_offset)
      end
    end
  end
end
