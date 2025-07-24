require "../../../test_spec_helper"

describe Hecate::Core::Renderer::JSON do
  describe "LSP-compatible JSON rendering" do
    it "emits a single error diagnostic as LSP JSON" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.cr", "def hello\n  world\nend")
      
      span = Hecate::Core::Span.new(source_id, 4, 9)  # "hello"
      diagnostic = Hecate.error("undefined method")
        .primary(span, "method not found")
        .help("try defining the method")
        .build
      
      renderer = Hecate::Core::Renderer::JSON.new(source_map)
      json_output = renderer.emit_string(diagnostic)
      
      json_output.should_not be_nil
      if json_output
        result = JSON.parse(json_output)
        
        # Check basic structure
        result["severity"].should eq 1  # Error
        result["source"].should eq "hecate"
        result["message"].as_s.should contain "undefined method"
        result["message"].as_s.should contain "try defining the method"
        
        # Check range
        range = result["range"]
        range["start"]["line"].should eq 0
        range["start"]["character"].should eq 4
        range["end"]["line"].should eq 0
        range["end"]["character"].should eq 9
      end
    end
    
    it "emits a warning diagnostic with secondary label" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.cr", "x = 5\ny = 10\nz = x + y")
      
      primary_span = Hecate::Core::Span.new(source_id, 16, 17)  # "x" in "z = x + y"
      secondary_span = Hecate::Core::Span.new(source_id, 0, 1)  # "x" in "x = 5"
      
      diagnostic = Hecate.warning("unused variable")
        .primary(primary_span, "used here")
        .secondary(secondary_span, "defined here")
        .note("consider removing if not needed")
        .build
      
      renderer = Hecate::Core::Renderer::JSON.new(source_map)
      json_output = renderer.emit_string(diagnostic)
      
      json_output.should_not be_nil
      if json_output
        result = JSON.parse(json_output)
        
        result["severity"].should eq 2  # Warning
        result["message"].as_s.should contain "unused variable"
        result["message"].as_s.should contain "consider removing if not needed"
        
        # Check related information
        if result["related_information"]?
          related = result["related_information"].as_a
          related.size.should eq 2  # Secondary label + note
          
          # Check secondary label
          secondary_info = related.find { |info| info["message"].as_s == "defined here" }
          secondary_info.should_not be_nil
          if secondary_info
            secondary_range = secondary_info["location"]["range"]
            secondary_range["start"]["line"].should eq 0
            secondary_range["start"]["character"].should eq 0
          end
        else
          fail "Expected related_information to be present"
        end
      end
    end
    
    it "handles diagnostics without primary labels gracefully" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.cr", "code")
      
      # Create diagnostic with only secondary labels (edge case)
      span = Hecate::Core::Span.new(source_id, 0, 4)
      diagnostic = Hecate.info("info message")
        .secondary(span, "related info")  # Only secondary, no primary
        .build
      
      renderer = Hecate::Core::Renderer::JSON.new(source_map)
      json_output = renderer.emit_string(diagnostic)
      
      # Should return nil for diagnostics without primary labels
      json_output.should be_nil
    end
    
    it "converts all severity levels correctly" do
      source_map = Hecate::Core::SourceMap.new
      source_id = source_map.add_file("test.cr", "test")
      span = Hecate::Core::Span.new(source_id, 0, 4)
      
      renderer = Hecate::Core::Renderer::JSON.new(source_map)
      
      # Test each severity level
      severities = [
        {Hecate::Core::Diagnostic::Severity::Error, 1},
        {Hecate::Core::Diagnostic::Severity::Warning, 2},
        {Hecate::Core::Diagnostic::Severity::Info, 3},
        {Hecate::Core::Diagnostic::Severity::Hint, 4}
      ]
      
      severities.each do |hecate_severity, lsp_severity|
        diagnostic = case hecate_severity
        when .error?
          Hecate.error("error message").primary(span, "error location").build
        when .warning?
          Hecate.warning("warning message").primary(span, "warning location").build
        when .info?
          Hecate.info("info message").primary(span, "info location").build
        when .hint?
          Hecate.hint("hint message").primary(span, "hint location").build
        else
          raise "Unknown severity"
        end
        
        json_output = renderer.emit_string(diagnostic)
        json_output.should_not be_nil
        if json_output
          result = JSON.parse(json_output)
          result["severity"].should eq lsp_severity
        end
      end
    end
    
    describe "batch rendering" do
      it "emits multiple diagnostics as JSON array" do
        source_map = Hecate::Core::SourceMap.new
        source_id = source_map.add_file("test.cr", "line1\nline2\nline3")
        
        diagnostics = [
          Hecate.error("error 1").primary(Hecate::Core::Span.new(source_id, 0, 5), "here").build,
          Hecate.warning("warning 1").primary(Hecate::Core::Span.new(source_id, 6, 11), "there").build,
          Hecate.info("info 1").primary(Hecate::Core::Span.new(source_id, 12, 17), "everywhere").build
        ]
        
        renderer = Hecate::Core::Renderer::JSON.new(source_map)
        json_output = renderer.emit_batch_string(diagnostics)
        
        result = JSON.parse(json_output).as_a
        result.size.should eq 3
        
        result[0]["severity"].should eq 1  # Error
        result[1]["severity"].should eq 2  # Warning  
        result[2]["severity"].should eq 3  # Info
      end
      
      it "filters diagnostics by severity" do
        source_map = Hecate::Core::SourceMap.new
        source_id = source_map.add_file("test.cr", "test code")
        
        diagnostics = [
          Hecate.error("error").primary(Hecate::Core::Span.new(source_id, 0, 4), "here").build,
          Hecate.warning("warning").primary(Hecate::Core::Span.new(source_id, 5, 9), "there").build,
          Hecate.error("another error").primary(Hecate::Core::Span.new(source_id, 0, 4), "here again").build
        ]
        
        renderer = Hecate::Core::Renderer::JSON.new(source_map)
        
        # Capture output for error-only filtering
        output = IO::Memory.new
        renderer.emit_by_severity(diagnostics, Hecate::Core::Diagnostic::Severity::Error, output)
        
        result = JSON.parse(output.to_s).as_a
        result.size.should eq 2  # Only the two errors
        result.all? { |d| d["severity"] == 1 }.should be_true
      end
    end
    
    describe "file URI conversion" do
      it "creates correct file URIs in grouped output" do
        source_map = Hecate::Core::SourceMap.new
        source_id = source_map.add_file("/home/user/project/file.cr", "test content")
        
        span = Hecate::Core::Span.new(source_id, 0, 4)
        diagnostic = Hecate.error("test").primary(span, "test location").build
        
        renderer = Hecate::Core::Renderer::JSON.new(source_map)
        output = IO::Memory.new
        renderer.emit_by_source([diagnostic], output)
        
        json_output = output.to_s
        json_output.should contain "file://"
        json_output.should contain "/home/user/project/file.cr"
      end
    end
    
    describe "LSP publishDiagnostics format" do
      it "emits diagnostics grouped by file in LSP format" do
        source_map = Hecate::Core::SourceMap.new
        file1_id = source_map.add_file("file1.cr", "content1")
        file2_id = source_map.add_file("file2.cr", "content2")
        
        diagnostics = [
          Hecate.error("error in file1").primary(Hecate::Core::Span.new(file1_id, 0, 7), "here").build,
          Hecate.warning("warning in file2").primary(Hecate::Core::Span.new(file2_id, 0, 7), "there").build,
          Hecate.info("info in file1").primary(Hecate::Core::Span.new(file1_id, 0, 7), "again").build
        ]
        
        renderer = Hecate::Core::Renderer::JSON.new(source_map)
        output = IO::Memory.new
        renderer.emit_lsp_publish_diagnostics(diagnostics, output)
        
        result = JSON.parse(output.to_s).as_a
        result.size.should eq 2  # Two files
        
        # Each result should be a publishDiagnostics notification
        result.each do |notification|
          notification["jsonrpc"].should eq "2.0"
          notification["method"].should eq "textDocument/publishDiagnostics"
          notification["params"]["uri"].as_s.should start_with "file://"
          notification["params"]["diagnostics"].as_a.size.should be > 0
        end
      end
    end
    
    describe "position conversion accuracy" do
      it "correctly converts multi-line spans to LSP positions" do
        source_content = "function test() {\n  var x = 5;\n  return x;\n}"
        source_map = Hecate::Core::SourceMap.new
        source_id = source_map.add_file("test.js", source_content)
        
        # Span covering "var x = 5" (line 1, chars 2-11)
        span = Hecate::Core::Span.new(source_id, 20, 29)  # "var x = 5"
        
        diagnostic = Hecate.error("unused variable")
          .primary(span, "declared here")
          .build
        
        renderer = Hecate::Core::Renderer::JSON.new(source_map)
        json_output = renderer.emit_string(diagnostic)
        
        json_output.should_not be_nil
        if json_output
          result = JSON.parse(json_output)
          range = result["range"]
          
          # Should be on line 1 (0-based), starting at character 2
          range["start"]["line"].should eq 1
          range["start"]["character"].should eq 2
          range["end"]["line"].should eq 1
          range["end"]["character"].should eq 11
        end
      end
      
      it "handles empty spans correctly" do
        source_map = Hecate::Core::SourceMap.new
        source_id = source_map.add_file("test.cr", "hello world")
        
        # Empty span (start == end)
        span = Hecate::Core::Span.new(source_id, 5, 5)  # Between "hello" and " world"
        
        diagnostic = Hecate.error("missing semicolon")
          .primary(span, "insert semicolon here")
          .build
        
        renderer = Hecate::Core::Renderer::JSON.new(source_map)
        json_output = renderer.emit_string(diagnostic)
        
        json_output.should_not be_nil
        if json_output
          result = JSON.parse(json_output)
          range = result["range"]
          
          # Start and end should be the same
          range["start"]["line"].should eq range["end"]["line"]
          range["start"]["character"].should eq range["end"]["character"]
          range["start"]["character"].should eq 5
        end
      end
    end
  end
end