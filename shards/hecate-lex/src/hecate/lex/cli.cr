module Hecate::Lex
  # Command-line interface utilities for lexer examples and tools
  module CLI
    # Result of parsing command-line arguments
    struct ParseResult
      getter input_path : String
      getter is_stdin : Bool
      getter extra_args : Array(String)

      def initialize(@input_path : String, @is_stdin : Bool, @extra_args = [] of String)
      end
    end

    # Parse command-line arguments
    #
    # Handles common patterns:
    # - No args: shows usage and exits
    # - Single "-": reads from stdin
    # - File path: reads from file
    # - Additional args after file path are captured
    #
    # Example:
    # ```
    # result = CLI.parse_args(ARGV, "my_lexer")
    # source = CLI.read_source(result.input_path)
    # ```
    def self.parse_args(args : Array(String), program_name : String,
                        usage_extra : String? = nil) : ParseResult
      if args.empty?
        show_usage(program_name, usage_extra)
        exit 1
      end

      input_path = args[0]
      is_stdin = input_path == "-"
      extra_args = args.size > 1 ? args[1..] : [] of String

      ParseResult.new(input_path, is_stdin, extra_args)
    end

    # Show usage information
    def self.show_usage(program_name : String, extra : String? = nil)
      puts "Usage: #{program_name} <source_file> [options]"
      puts "   or: #{program_name} - [options]"
      puts "        (read from stdin)"

      if extra
        puts
        puts extra
      end
    end

    # Read source code from file or stdin
    #
    # Example:
    # ```
    # source = CLI.read_source(result.input_path)
    # ```
    def self.read_source(path : String) : String
      if path == "-"
        STDIN.gets_to_end
      else
        begin
          File.read(path)
        rescue ex : File::NotFoundError
          STDERR.puts "Error: File not found: #{path}"
          exit 1
        rescue ex
          STDERR.puts "Error reading file: #{ex.message}"
          exit 1
        end
      end
    end

    # Create a source file and source map
    #
    # Returns a tuple of {source_map, source_file}
    #
    # Example:
    # ```
    # source_map, source_file = CLI.create_source_file(path, content)
    # ```
    def self.create_source_file(path : String, content : String) : {Hecate::Core::SourceMap, Hecate::Core::SourceFile}
      source_map = Hecate::Core::SourceMap.new
      display_path = path == "-" ? "<stdin>" : path
      source_id = source_map.add_file(display_path, content)
      source_file = source_map.get(source_id).not_nil!

      {source_map, source_file}
    end

    # Complete helper that combines parsing, reading, and source file creation
    #
    # Example:
    # ```
    # result, source_map, source_file = CLI.setup(ARGV, "my_lexer")
    # ```
    def self.setup(args : Array(String), program_name : String,
                   usage_extra : String? = nil) : {ParseResult, Hecate::Core::SourceMap, Hecate::Core::SourceFile}
      result = parse_args(args, program_name, usage_extra)
      content = read_source(result.input_path)
      source_map, source_file = create_source_file(result.input_path, content)

      {result, source_map, source_file}
    end

    # Format file size for display
    def self.format_file_size(bytes : Int32) : String
      if bytes < 1024
        "#{bytes} bytes"
      elsif bytes < 1024 * 1024
        "#{(bytes / 1024.0).round(1)} KB"
      else
        "#{(bytes / (1024.0 * 1024.0)).round(1)} MB"
      end
    end

    # Print a header for output sections
    def self.print_header(title : String, io : IO = STDOUT)
      io.puts "=== #{title} ==="
      io.puts
    end

    # Print a summary section
    def self.print_summary(stats : NamedTuple | Hash, io : IO = STDOUT)
      print_header("Summary", io)

      stats.each do |key, value|
        # Convert key to title case
        title = key.to_s.split('_').map(&.capitalize).join(' ')
        io.puts "#{title}: #{value}"
      end
    end
  end
end
