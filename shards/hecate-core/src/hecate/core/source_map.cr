require "mutex"

module Hecate::Core
  # Thread-safe registry for managing multiple source files
  class SourceMap
    private getter sources = {} of UInt32 => SourceFile
    private getter paths = {} of String => UInt32
    private property next_id = 1_u32
    private getter mutex = Mutex.new

    def initialize
    end

    # Add a source file to the map
    def add_file(path : String, contents : String) : UInt32
      mutex.synchronize do
        # Return existing ID if path already registered
        return paths[path] if paths.has_key?(path)

        # Generate new ID
        id = self.next_id
        self.next_id += 1

        # Create and store source file
        source = SourceFile.new(id, path, contents)
        sources[id] = source
        paths[path] = id

        id
      end
    end

    # Add a virtual file (e.g., for REPL or generated code)
    def add_virtual(name : String, contents : String) : UInt32
      add_file("<#{name}>", contents)
    end

    # Get a source file by ID
    def get(id : UInt32) : SourceFile?
      mutex.synchronize { sources[id]? }
    end

    # Get a source file by path
    def get_by_path(path : String) : SourceFile?
      mutex.synchronize do
        if id = paths[path]?
          sources[id]?
        end
      end
    end

    # Convert a span to start and end positions
    def span_to_position(span : Span) : {Position, Position}?
      source = get(span.source_id)
      return nil unless source

      start_pos = source.byte_to_position(span.start_byte)
      end_pos = source.byte_to_position(span.end_byte)

      {start_pos, end_pos}
    end

    # Iterate over all source files
    def each_source(& : SourceFile ->)
      mutex.synchronize do
        sources.each_value { |source| yield source }
      end
    end

    # Get the number of registered files
    def size : Int32
      mutex.synchronize { sources.size }
    end

    # Check if a path is registered
    def has_file?(path : String) : Bool
      mutex.synchronize { paths.has_key?(path) }
    end

    # Clear all registered files (useful for testing)
    def clear
      mutex.synchronize do
        sources.clear
        paths.clear
        self.next_id = 1_u32
      end
    end
  end
end
