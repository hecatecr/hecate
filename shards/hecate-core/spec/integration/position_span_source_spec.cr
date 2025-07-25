require "../spec_helper"

describe "Position, Span, and SourceFile integration" do
  it "converts between spans and positions" do
    content = "line 1\nline 2\nline 3"
    source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

    # Create a span covering "line 2"
    span = Hecate::Core::Span.new(1_u32, 7, 13)

    # Convert span boundaries to positions
    start_pos = source.byte_to_position(span.start_byte)
    end_pos = source.byte_to_position(span.end_byte)

    start_pos.line.should eq(1)
    start_pos.column.should eq(0)
    end_pos.line.should eq(1)   # Still on line 1 (second line)
    end_pos.column.should eq(6) # At position 6 of "line 2"

    # Convert positions back to bytes
    source.position_to_byte(start_pos).should eq(7)
    source.position_to_byte(end_pos).should eq(13)
  end

  it "extracts text covered by a span" do
    content = "hello world\nthis is a test\nfinal line"
    source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

    # Span covering "is a"
    span = Hecate::Core::Span.new(1_u32, 17, 21)

    # Extract the text
    text = content[span.start_byte...span.end_byte]
    text.should eq("is a")
  end

  it "handles spans across multiple lines" do
    content = "first line\nsecond line\nthird line"
    source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

    # Span from middle of first line to middle of second
    span = Hecate::Core::Span.new(1_u32, 6, 18)

    start_pos = source.byte_to_position(span.start_byte)
    end_pos = source.byte_to_position(span.end_byte)

    start_pos.should eq(Hecate::Core::Position.new(0, 6))
    end_pos.should eq(Hecate::Core::Position.new(1, 7))

    # Extract covered text
    text = content[span.start_byte...span.end_byte]
    text.should eq("line\nsecond ")
  end

  it "formats diagnostic-friendly location strings" do
    source = Hecate::Core::SourceFile.new(1_u32, "example.cr", "def foo\n  puts 42\nend")

    # Span covering "puts 42"
    span = Hecate::Core::Span.new(1_u32, 10, 17)
    start_pos = source.byte_to_position(span.start_byte)

    # Create a diagnostic-friendly string
    location = "#{source.path}:#{start_pos}"
    location.should eq("example.cr:2:3")
  end

  it "handles CRLF line endings correctly" do
    content = "line 1\r\nline 2\r\nline 3"
    source = Hecate::Core::SourceFile.new(1_u32, "test.cr", content)

    # Span covering "line 2"
    span = Hecate::Core::Span.new(1_u32, 8, 14)

    start_pos = source.byte_to_position(span.start_byte)
    end_pos = source.byte_to_position(span.end_byte)

    start_pos.line.should eq(1)
    start_pos.column.should eq(0)

    # Extract the line
    line = source.line_at(start_pos.line)
    line.should eq("line 2")
  end

  it "supports sorting positions" do
    positions = [
      Hecate::Core::Position.new(2, 5),
      Hecate::Core::Position.new(1, 10),
      Hecate::Core::Position.new(1, 5),
      Hecate::Core::Position.new(3, 0),
    ]

    sorted = positions.sort
    sorted.map(&.to_s).should eq(["2:6", "2:11", "3:6", "4:1"])
  end

  it "merges overlapping spans for error reporting" do
    # Two error spans that should be merged
    error1 = Hecate::Core::Span.new(1_u32, 10, 20)
    error2 = Hecate::Core::Span.new(1_u32, 15, 25)

    merged = error1.merge(error2)
    merged.length.should eq(15) # 10 to 25
  end
end
