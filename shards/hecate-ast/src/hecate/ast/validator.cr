require "./node"
require "hecate-core"

module Hecate::AST
  # ASTValidator is a visitor that traverses AST nodes and collects validation errors
  # It automatically calls the validate method on nodes that define validation rules
  class ASTValidator
    getter errors : Array(Hecate::Core::Diagnostic)

    def initialize
      @errors = [] of Hecate::Core::Diagnostic
    end

    # Visit a node and accumulate any validation errors
    def visit(node : Node) : Nil
      # Check if this node has validation rules
      if node.responds_to?(:validate)
        node_errors = node.validate
        @errors.concat(node_errors)
      end

      # Continue traversing child nodes
      node.children.each do |child|
        visit(child)
      end
    end

    # Clear accumulated errors
    def clear
      @errors.clear
    end

    # Check if any errors were found
    def valid? : Bool
      @errors.empty?
    end

    # Get errors by severity level
    def errors_by_severity(severity : Hecate::Core::Diagnostic::Severity) : Array(Hecate::Core::Diagnostic)
      @errors.select { |error| error.severity == severity }
    end

    # Get only error-level diagnostics
    def errors_only : Array(Hecate::Core::Diagnostic)
      errors_by_severity(Hecate::Core::Diagnostic::Severity::Error)
    end

    # Get only warning-level diagnostics
    def warnings_only : Array(Hecate::Core::Diagnostic)
      errors_by_severity(Hecate::Core::Diagnostic::Severity::Warning)
    end

    # Get only hint-level diagnostics
    def hints_only : Array(Hecate::Core::Diagnostic)
      errors_by_severity(Hecate::Core::Diagnostic::Severity::Hint)
    end

    # Get only info-level diagnostics
    def info_only : Array(Hecate::Core::Diagnostic)
      errors_by_severity(Hecate::Core::Diagnostic::Severity::Info)
    end

    # Get count of errors by severity level
    def error_count : Int32
      errors_only.size
    end

    def warning_count : Int32
      warnings_only.size
    end

    def hint_count : Int32
      hints_only.size
    end

    def info_count : Int32
      info_only.size
    end

    # Create a summary string of validation results
    def summary : String
      if valid?
        "Validation passed: no errors found"
      else
        parts = [] of String
        parts << "#{error_count} errors" if error_count > 0
        parts << "#{warning_count} warnings" if warning_count > 0
        parts << "#{hint_count} hints" if hint_count > 0
        parts << "#{info_count} info" if info_count > 0
        "Validation failed: #{parts.join(", ")}"
      end
    end
  end
end