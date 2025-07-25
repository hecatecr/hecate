# Entry point for hecate-core test utilities
# This allows other shards to require "hecate-core/test_utils"

require "./hecate-core"
require "./hecate/core/test_utils"
require "./hecate/core/test_spec_helper"

# Make test utilities available at top level for specs
include Hecate::Core::TestUtils::Helpers
