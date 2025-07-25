require "json"
require "yaml"
require "file_utils"

module Hecate::Core
  # Base test utilities for the Hecate project
  module TestUtils
    # Represents a test case with expected input and output
    abstract struct TestCase
      abstract def input : String
      abstract def description : String
    end

    # A test case that expects successful processing
    struct SuccessCase(T) < TestCase
      getter input : String
      getter expected : T
      getter description : String

      def initialize(@input : String, @expected : T, @description : String)
      end
    end

    # A test case that expects an error
    struct ErrorCase < TestCase
      getter input : String
      getter expected_error : String | Regex
      getter description : String

      def initialize(@input : String, @expected_error : String | Regex, @description : String)
      end
    end

    # Snapshot testing utilities
    module Snapshot
      # Default snapshot directory relative to spec directory
      SNAPSHOT_DIR = "__snapshots__"

      # Records or verifies a snapshot
      def self.match(name : String, actual : String, *, update = false) : Nil
        snapshot_path = snapshot_path_for(name)

        if update || !File.exists?(snapshot_path)
          # Create or update snapshot
          Dir.mkdir_p(File.dirname(snapshot_path))
          File.write(snapshot_path, actual)
          return
        end

        # Compare with existing snapshot
        expected = File.read(snapshot_path)
        if actual != expected
          raise SnapshotMismatch.new(name, expected, actual)
        end
      end

      # Match snapshot with automatic formatting
      def self.match_formatted(name : String, actual : String, *, update = false) : Nil
        # Normalize line endings and trailing whitespace
        normalized = actual.lines.map(&.rstrip).join('\n').rstrip + '\n'
        match(name, normalized, update: update)
      end

      # Match a data structure as YAML snapshot
      def self.match_yaml(name : String, actual, *, update = false) : Nil
        yaml_content = actual.to_yaml
        match("#{name}.yaml", yaml_content, update: update)
      end

      # Match a data structure as JSON snapshot
      def self.match_json(name : String, actual, *, update = false) : Nil
        json_content = JSON.parse(actual.to_json).to_pretty_json
        match("#{name}.json", json_content, update: update)
      end

      # Get the snapshot path for a given name
      private def self.snapshot_path_for(name : String) : String
        # Get the spec file path from the call stack
        caller_file = ""
        caller.each do |frame|
          if match = frame.match(/^(.+_spec\.cr):\d+/)
            caller_file = match[1]
            break
          end
        end

        if caller_file.empty?
          raise "Could not determine spec file location"
        end

        # Build snapshot path relative to spec file
        spec_dir = File.dirname(caller_file)
        File.join(spec_dir, SNAPSHOT_DIR, "#{name}.snap")
      end

      # Exception raised when snapshot doesn't match
      class SnapshotMismatch < Exception
        getter name : String
        getter expected : String
        getter actual : String

        def initialize(@name : String, @expected : String, @actual : String)
          super(build_message)
        end

        private def build_message : String
          diff = generate_diff(expected, actual)
          <<-MSG
          Snapshot mismatch for '#{name}':
          
          #{diff}
          
          To update this snapshot, run with UPDATE_SNAPSHOTS=1
          MSG
        end

        private def generate_diff(expected : String, actual : String) : String
          expected_lines = expected.lines
          actual_lines = actual.lines

          diff_lines = [] of String
          diff_lines << "Expected:"
          expected_lines.each_with_index do |line, i|
            if i < actual_lines.size && line != actual_lines[i]
              diff_lines << "- #{line}"
            else
              diff_lines << "  #{line}"
            end
          end

          diff_lines << "\nActual:"
          actual_lines.each_with_index do |line, i|
            if i < expected_lines.size && line != expected_lines[i]
              diff_lines << "+ #{line}"
            elsif i >= expected_lines.size
              diff_lines << "+ #{line}"
            else
              diff_lines << "  #{line}"
            end
          end

          diff_lines.join('\n')
        end
      end
    end

    # Golden file testing utilities
    module GoldenFile
      # Default golden file directory
      GOLDEN_DIR = "golden"

      # Test against a golden file
      def self.test(name : String, actual : String, *, update = false) : Nil
        golden_path = golden_path_for(name)

        if update || !File.exists?(golden_path)
          # Create or update golden file
          Dir.mkdir_p(File.dirname(golden_path))
          File.write(golden_path, actual)
          return
        end

        # Compare with golden file
        expected = File.read(golden_path)
        if actual != expected
          raise GoldenFileMismatch.new(name, expected, actual)
        end
      end

      # Get the golden file path
      private def self.golden_path_for(name : String) : String
        # Golden files are stored in spec/fixtures/golden
        # When running from monorepo root, we need to find the actual shard directory
        spec_dir = find_spec_directory
        File.join(spec_dir, "fixtures", GOLDEN_DIR, name)
      end

      # Find the spec directory by looking up from the current test file
      private def self.find_spec_directory : String
        # Get the calling spec file location from the call stack
        caller_location = caller.find { |loc| loc.includes?("_spec.cr") }
        if caller_location.nil?
          raise "Could not determine spec file location"
        end
        
        # Extract the file path from the caller location
        # Format is like "path/to/file.cr:123:4 in 'method'"
        spec_file = caller_location.split(':').first
        spec_file_dir = File.dirname(spec_file)
        
        # Walk up to find the spec directory
        current = spec_file_dir
        loop do
          if File.basename(current) == "spec"
            return current
          end
          parent = File.dirname(current)
          break if parent == current
          current = parent
        end
        
        raise "Could not find spec directory"
      end

      # Find project root by looking for shard.yml
      private def self.find_project_root : String
        current = Dir.current
        loop do
          if File.exists?(File.join(current, "shard.yml"))
            return current
          end
          parent = File.dirname(current)
          break if parent == current
          current = parent
        end
        raise "Could not find project root (no shard.yml found)"
      end

      # Exception for golden file mismatches
      class GoldenFileMismatch < Exception
        getter name : String
        getter expected : String
        getter actual : String

        def initialize(@name : String, @expected : String, @actual : String)
          super("Golden file mismatch for '#{name}'. Run with UPDATE_GOLDEN=1 to update.")
        end
      end
    end

    # Test data generators
    module Generators
      # Generate random valid identifiers
      def self.identifier(length : Int32 = 8) : String
        chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + ['_']
        first_chars = ('a'..'z').to_a + ('A'..'Z').to_a + ['_']

        String.build(length) do |str|
          str << first_chars.sample
          (length - 1).times { str << chars.sample }
        end
      end

      # Generate random source code snippets
      def self.source_snippet(lines : Int32 = 5) : String
        templates = [
          "let #{identifier} = #{Random.rand(100)}",
          "func #{identifier}() { }",
          "if #{identifier} { #{identifier}() }",
          "return #{identifier}",
          "// #{identifier} comment",
        ]

        Array.new(lines) { templates.sample }.join('\n')
      end

      # Generate random spans
      def self.span(source_id : UInt32 = 0_u32, max_offset : Int32 = 1000) : Span
        start = Random.rand(max_offset)
        length = Random.rand(1..20)
        Span.new(source_id, start, start + length)
      end
    end

    # Spec helper macros
    macro test_cases(cases, &block)
      {% for test_case in cases %}
        it {{ test_case[:description] }} do
          input = {{ test_case[:input] }}
          {% if test_case[:expected] %}
            expected = {{ test_case[:expected] }}
          {% end %}
          {% if test_case[:error] %}
            expected_error = {{ test_case[:error] }}
          {% end %}
          
          {{ block.body }}
        end
      {% end %}
    end

    # Run snapshot tests with automatic update based on environment
    macro snapshot_test(name, value)
      update_snapshots = ENV["UPDATE_SNAPSHOTS"]? == "1"
      Hecate::Core::TestUtils::Snapshot.match({{ name }}, {{ value }}, update: update_snapshots)
    end

    # Run golden file tests with automatic update based on environment
    macro golden_test(name, value)
      update_golden = ENV["UPDATE_GOLDEN"]? == "1"
      Hecate::Core::TestUtils::GoldenFile.test({{ name }}, {{ value }}, update: update_golden)
    end
  end
end
