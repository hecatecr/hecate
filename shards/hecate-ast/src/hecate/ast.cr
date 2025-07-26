require "hecate-core"

module Hecate
  module AST
    VERSION = "0.1.0"

    # Forward core diagnostics for convenience
    def self.error(message : String)
      Hecate.error(message)
    end

    def self.warning(message : String)
      Hecate.warning(message)
    end

    def self.info(message : String)
      Hecate.info(message)
    end

    def self.hint(message : String)
      Hecate.hint(message)
    end

  end
end

# Require all AST modules
require "./ast/node"
require "./ast/dsl"
require "./ast/visitor"
require "./ast/traversal"
require "./ast/pretty_printer"
require "./ast/validator"
# require "./ast/builder"