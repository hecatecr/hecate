require "spec"
require "../src/hecate-lex"

# Include comprehensive test utilities from hecate-core
require "hecate-core/test_utils"

# Import core classes needed for testing
include Hecate::Core

# Helper aliases for tests
alias SourceMap = Hecate::Core::SourceMap
alias SourceFile = Hecate::Core::SourceFile
alias Span = Hecate::Core::Span
alias Diagnostic = Hecate::Core::Diagnostic
