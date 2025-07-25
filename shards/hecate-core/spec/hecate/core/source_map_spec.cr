require "../../spec_helper"

describe Hecate::Core::SourceMap do
  describe "#initialize" do
    it "creates empty source map" do
      map = Hecate::Core::SourceMap.new
      map.size.should eq(0)
    end
  end

  describe "#add_file" do
    it "adds new file and returns unique ID" do
      map = Hecate::Core::SourceMap.new

      id1 = map.add_file("file1.cr", "content 1")
      id2 = map.add_file("file2.cr", "content 2")

      id1.should eq(1_u32)
      id2.should eq(2_u32)
      map.size.should eq(2)
    end

    it "returns same ID for duplicate paths" do
      map = Hecate::Core::SourceMap.new

      id1 = map.add_file("test.cr", "content 1")
      id2 = map.add_file("test.cr", "content 2") # Same path, different content

      id1.should eq(id2)
      map.size.should eq(1)

      # Verify original content is preserved
      source = map.get(id1)
      source.not_nil!.contents.should eq("content 1")
    end

    it "handles concurrent additions safely" do
      map = Hecate::Core::SourceMap.new
      channel = Channel(UInt32).new

      # Spawn multiple fibers adding files concurrently
      10.times do |i|
        spawn do
          id = map.add_file("file#{i}.cr", "content #{i}")
          channel.send(id)
        end
      end

      # Collect all IDs
      ids = Array(UInt32).new
      10.times { ids << channel.receive }

      # Verify all IDs are unique
      ids.uniq.size.should eq(10)
      map.size.should eq(10)
    end
  end

  describe "#add_virtual" do
    it "wraps name in angle brackets" do
      map = Hecate::Core::SourceMap.new

      id = map.add_virtual("repl", "puts 42")
      source = map.get(id)

      source.not_nil!.path.should eq("<repl>")
      source.not_nil!.contents.should eq("puts 42")
    end
  end

  describe "#get" do
    it "retrieves source file by ID" do
      map = Hecate::Core::SourceMap.new
      id = map.add_file("test.cr", "hello world")

      source = map.get(id)
      source.should_not be_nil
      source.not_nil!.path.should eq("test.cr")
      source.not_nil!.contents.should eq("hello world")
    end

    it "returns nil for invalid ID" do
      map = Hecate::Core::SourceMap.new
      map.get(999_u32).should be_nil
    end
  end

  describe "#get_by_path" do
    it "retrieves source file by path" do
      map = Hecate::Core::SourceMap.new
      map.add_file("test.cr", "content")

      source = map.get_by_path("test.cr")
      source.should_not be_nil
      source.not_nil!.contents.should eq("content")
    end

    it "returns nil for unregistered path" do
      map = Hecate::Core::SourceMap.new
      map.get_by_path("unknown.cr").should be_nil
    end
  end

  describe "#span_to_position" do
    it "converts span to position tuple" do
      map = Hecate::Core::SourceMap.new
      id = map.add_file("test.cr", "line 1\nline 2\nline 3")

      # Span covering "line 2"
      span = Hecate::Core::Span.new(id, 7, 13)
      positions = map.span_to_position(span)

      positions.should_not be_nil
      start_pos, end_pos = positions.not_nil!

      start_pos.line.should eq(1)
      start_pos.column.should eq(0)
      end_pos.line.should eq(1)
      end_pos.column.should eq(6)
    end

    it "returns nil for invalid source ID" do
      map = Hecate::Core::SourceMap.new
      span = Hecate::Core::Span.new(999_u32, 0, 10)

      map.span_to_position(span).should be_nil
    end
  end

  describe "#each_source" do
    it "iterates over all source files" do
      map = Hecate::Core::SourceMap.new
      map.add_file("file1.cr", "content 1")
      map.add_file("file2.cr", "content 2")
      map.add_file("file3.cr", "content 3")

      paths = [] of String
      map.each_source { |source| paths << source.path }

      paths.sort.should eq(["file1.cr", "file2.cr", "file3.cr"])
    end
  end

  describe "#has_file?" do
    it "checks if path is registered" do
      map = Hecate::Core::SourceMap.new
      map.add_file("exists.cr", "content")

      map.has_file?("exists.cr").should be_true
      map.has_file?("missing.cr").should be_false
    end
  end

  describe "#clear" do
    it "removes all files and resets ID counter" do
      map = Hecate::Core::SourceMap.new

      # Add some files
      map.add_file("file1.cr", "content 1")
      map.add_file("file2.cr", "content 2")
      map.size.should eq(2)

      # Clear the map
      map.clear
      map.size.should eq(0)
      map.has_file?("file1.cr").should be_false

      # Verify ID counter is reset
      id = map.add_file("new.cr", "new content")
      id.should eq(1_u32)
    end
  end

  describe "thread safety" do
    it "handles concurrent operations safely" do
      map = Hecate::Core::SourceMap.new
      errors = Channel(Exception?).new
      done = Channel(Nil).new

      # Multiple concurrent operations
      spawn do
        100.times do |i|
          map.add_file("file#{i}.cr", "content #{i}")
        end
        done.send(nil)
      rescue e
        errors.send(e)
      end

      spawn do
        100.times do
          map.size
          map.each_source { |s| s.path }
        end
        done.send(nil)
      rescue e
        errors.send(e)
      end

      spawn do
        50.times do |i|
          if source = map.get(i.to_u32)
            source.path
          end
        end
        done.send(nil)
      rescue e
        errors.send(e)
      end

      # Wait for all operations to complete
      3.times { done.receive }

      # Check for errors
      select
      when error = errors.receive
        raise error if error
      else
        # No errors
      end

      # Verify final state
      map.size.should eq(100)
    end
  end
end
