require "json"
require "../span"
require "../position"
require "../source_file"
require "../diagnostic"
require "../diagnostic_builder"
require "../source_map"

module Hecate::Core::Renderer
  # JSON diagnostic renderer that outputs LSP-compatible diagnostic format
  class JSON
    getter source_map : SourceMap

    def initialize(@source_map : SourceMap)
    end

    # LSP diagnostic severity levels
    enum LSPSeverity
      Error       = 1
      Warning     = 2
      Information = 3
      Hint        = 4
    end

    # LSP Position structure (0-based line and character)
    struct LSPPosition
      include ::JSON::Serializable

      getter line : Int32
      getter character : Int32

      def initialize(@line : Int32, @character : Int32)
      end
    end

    # LSP Range structure (start and end positions)
    struct LSPRange
      include ::JSON::Serializable

      getter start : LSPPosition
      getter end : LSPPosition

      def initialize(@start : LSPPosition, @end : LSPPosition)
      end
    end

    # LSP DiagnosticRelatedInformation structure
    struct LSPRelatedInformation
      include ::JSON::Serializable

      getter location : LSPLocation
      getter message : String

      def initialize(@location : LSPLocation, @message : String)
      end
    end

    # LSP Location structure (URI and range)
    struct LSPLocation
      include ::JSON::Serializable

      getter uri : String
      getter range : LSPRange

      def initialize(@uri : String, @range : LSPRange)
      end
    end

    # Main LSP Diagnostic structure
    struct LSPDiagnostic
      include ::JSON::Serializable

      getter range : LSPRange
      getter severity : Int32
      getter source : String
      getter message : String
      getter code : String?
      getter related_information : Array(LSPRelatedInformation)?

      def initialize(@range : LSPRange, @severity : Int32, @source : String,
                     @message : String, @code : String? = nil,
                     @related_information : Array(LSPRelatedInformation)? = nil)
      end
    end

    # Convert Hecate diagnostic severity to LSP severity
    private def convert_severity(severity : Diagnostic::Severity) : Int32
      case severity
      when .error?
        LSPSeverity::Error.value
      when .warning?
        LSPSeverity::Warning.value
      when .info?
        LSPSeverity::Information.value
      when .hint?
        LSPSeverity::Hint.value
      else
        LSPSeverity::Error.value # Default to error for unknown severity
      end
    end

    # Convert a Hecate span to LSP range
    private def span_to_lsp_range(span : Span) : LSPRange?
      source_file = @source_map.get(span.source_id)
      return nil unless source_file

      start_pos = source_file.byte_to_position(span.start_byte)
      end_pos = source_file.byte_to_position(span.end_byte)

      lsp_start = LSPPosition.new(start_pos.line, start_pos.column)
      lsp_end = LSPPosition.new(end_pos.line, end_pos.column)

      LSPRange.new(lsp_start, lsp_end)
    end

    # Convert source file path to LSP URI format
    private def path_to_uri(path : String) : String
      # Convert file path to file:// URI
      if path.starts_with?("/")
        "file://#{path}"
      else
        "file://#{File.expand_path(path)}"
      end
    end

    # Emit a single diagnostic as LSP-compatible JSON
    def emit(diagnostic : Diagnostic, io : IO = STDOUT) : Nil
      lsp_diagnostic = convert_diagnostic(diagnostic)
      return unless lsp_diagnostic

      lsp_diagnostic.to_json(io)
    end

    # Overload to accept DiagnosticBuilder
    def emit(diagnostic_builder : DiagnosticBuilder, io : IO = STDOUT) : Nil
      emit(diagnostic_builder.build, io)
    end

    # Emit a single diagnostic and return the JSON string
    def emit_string(diagnostic : Diagnostic) : String?
      lsp_diagnostic = convert_diagnostic(diagnostic)
      return nil unless lsp_diagnostic

      lsp_diagnostic.to_json
    end

    # Overload to accept DiagnosticBuilder
    def emit_string(diagnostic_builder : DiagnosticBuilder) : String?
      emit_string(diagnostic_builder.build)
    end

    # Emit multiple diagnostics as a JSON array
    def emit_batch(diagnostics : Array(Diagnostic), io : IO = STDOUT) : Nil
      lsp_diagnostics = [] of LSPDiagnostic

      diagnostics.each do |diagnostic|
        if lsp_diagnostic = convert_diagnostic(diagnostic)
          lsp_diagnostics << lsp_diagnostic
        end
      end

      lsp_diagnostics.to_json(io)
    end

    # Emit multiple diagnostics and return the JSON string
    def emit_batch_string(diagnostics : Array(Diagnostic)) : String
      lsp_diagnostics = [] of LSPDiagnostic

      diagnostics.each do |diagnostic|
        if lsp_diagnostic = convert_diagnostic(diagnostic)
          lsp_diagnostics << lsp_diagnostic
        end
      end

      lsp_diagnostics.to_json
    end

    # Overload to accept Array(DiagnosticBuilder)
    def emit_batch(diagnostic_builders : Array(DiagnosticBuilder), io : IO = STDOUT) : Nil
      diagnostics = diagnostic_builders.map(&.build)
      emit_batch(diagnostics, io)
    end

    # Overload to accept Array(DiagnosticBuilder)
    def emit_batch_string(diagnostic_builders : Array(DiagnosticBuilder)) : String
      diagnostics = diagnostic_builders.map(&.build)
      emit_batch_string(diagnostics)
    end

    # Overload to accept Array(DiagnosticBuilder)
    def emit_by_severity(diagnostic_builders : Array(DiagnosticBuilder), severity : Diagnostic::Severity, io : IO = STDOUT) : Nil
      diagnostics = diagnostic_builders.map(&.build)
      emit_by_severity(diagnostics, severity, io)
    end

    # Overload to accept Array(DiagnosticBuilder)
    def emit_by_source(diagnostic_builders : Array(DiagnosticBuilder), io : IO = STDOUT) : Nil
      diagnostics = diagnostic_builders.map(&.build)
      emit_by_source(diagnostics, io)
    end

    # Overload to accept Array(DiagnosticBuilder)
    def emit_lsp_publish_diagnostics(diagnostic_builders : Array(DiagnosticBuilder), io : IO = STDOUT) : Nil
      diagnostics = diagnostic_builders.map(&.build)
      emit_lsp_publish_diagnostics(diagnostics, io)
    end

    # Filter diagnostics by severity and emit as JSON array
    def emit_by_severity(diagnostics : Array(Diagnostic), severity : Diagnostic::Severity, io : IO = STDOUT) : Nil
      filtered = diagnostics.select { |d| d.severity == severity }
      emit_batch(filtered, io)
    end

    # Group diagnostics by source file and emit as a hash
    def emit_by_source(diagnostics : Array(Diagnostic), io : IO = STDOUT) : Nil
      grouped = {} of String => Array(LSPDiagnostic)

      diagnostics.each do |diagnostic|
        if lsp_diagnostic = convert_diagnostic(diagnostic)
          # Get the source URI from the primary label
          primary_label = diagnostic.labels.find(&.style.primary?)
          next unless primary_label

          source_file = @source_map.get(primary_label.span.source_id)
          next unless source_file

          uri = path_to_uri(source_file.path)
          grouped[uri] ||= [] of LSPDiagnostic
          grouped[uri] << lsp_diagnostic
        end
      end

      grouped.to_json(io)
    end

    # Emit diagnostics in LSP publishDiagnostics format
    def emit_lsp_publish_diagnostics(diagnostics : Array(Diagnostic), io : IO = STDOUT) : Nil
      grouped = {} of String => Array(LSPDiagnostic)

      diagnostics.each do |diagnostic|
        if lsp_diagnostic = convert_diagnostic(diagnostic)
          # Get the source URI from the primary label
          primary_label = diagnostic.labels.find(&.style.primary?)
          next unless primary_label

          source_file = @source_map.get(primary_label.span.source_id)
          next unless source_file

          uri = path_to_uri(source_file.path)
          grouped[uri] ||= [] of LSPDiagnostic
          grouped[uri] << lsp_diagnostic
        end
      end

      # Emit in LSP publishDiagnostics format for each file
      results = [] of Hash(String, String | Hash(String, String | Array(LSPDiagnostic)))
      grouped.each do |uri, file_diagnostics|
        results << {
          "jsonrpc" => "2.0",
          "method"  => "textDocument/publishDiagnostics",
          "params"  => {
            "uri"         => uri,
            "diagnostics" => file_diagnostics,
          }.as(Hash(String, String | Array(LSPDiagnostic))),
        }
      end

      results.to_json(io)
    end

    # Convert a Hecate diagnostic to LSP diagnostic
    private def convert_diagnostic(diagnostic : Diagnostic) : LSPDiagnostic?
      # Find the primary label (main error location)
      primary_label = diagnostic.labels.find(&.style.primary?)
      return nil unless primary_label

      # Convert primary span to LSP range
      range = span_to_lsp_range(primary_label.span)
      return nil unless range

      # Get source file for URI
      source_file = @source_map.get(primary_label.span.source_id)
      return nil unless source_file

      uri = path_to_uri(source_file.path)
      severity = convert_severity(diagnostic.severity)

      # Convert secondary labels to related information
      related_info = [] of LSPRelatedInformation
      diagnostic.labels.each do |label|
        next if label.style.primary?

        if secondary_range = span_to_lsp_range(label.span)
          if secondary_source = @source_map.get(label.span.source_id)
            secondary_uri = path_to_uri(secondary_source.path)
            location = LSPLocation.new(secondary_uri, secondary_range)
            related_info << LSPRelatedInformation.new(location, label.message)
          end
        end
      end

      # Include notes as related information if any
      diagnostic.notes.each do |note|
        # Notes don't have specific locations, so we use the primary location
        location = LSPLocation.new(uri, range)
        related_info << LSPRelatedInformation.new(location, note)
      end

      # Combine message with help and notes if available
      full_message = diagnostic.message
      if help = diagnostic.help
        full_message += "\n#{help}"
      end

      # Include notes in the message as well as related information
      unless diagnostic.notes.empty?
        diagnostic.notes.each do |note|
          full_message += "\n#{note}"
        end
      end

      LSPDiagnostic.new(
        range: range,
        severity: severity,
        source: "hecate",
        message: full_message,
        related_information: related_info.empty? ? nil : related_info
      )
    end
  end
end
