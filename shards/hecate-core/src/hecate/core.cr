module Hecate
  module Core
    VERSION = "0.1.0"

    # Core module for Hecate language development toolkit
    # This module provides:
    # - Source file management and mapping
    # - Position and span tracking
    # - Diagnostic system with beautiful error rendering
    # - Utilities for language implementation
  end

  # Convenience methods that delegate to Hecate::Core
  # These provide a shorter API for common diagnostic creation
  def self.error(message : String) : Core::DiagnosticBuilder
    Core.error(message)
  end

  def self.warning(message : String) : Core::DiagnosticBuilder
    Core.warning(message)
  end

  def self.info(message : String) : Core::DiagnosticBuilder
    Core.info(message)
  end

  def self.hint(message : String) : Core::DiagnosticBuilder
    Core.hint(message)
  end
end
