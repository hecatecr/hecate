# Node pooling system for memory optimization
# Provides shared instances of commonly used literal nodes

module Hecate::AST
  # Thread-safe node pool for reusing common literal values
  module NodePool
    extend self

    # Pool for common integer literals (-128 to 127)
    private INT_POOL       = {} of Int32 => ::Hecate::AST::Node
    private INT_POOL_MUTEX = Mutex.new

    # Pool for boolean literals (true/false singletons)
    private BOOL_POOL       = {} of Bool => ::Hecate::AST::Node
    private BOOL_POOL_MUTEX = Mutex.new

    # Pool for common string literals (cache up to 1000 strings)
    private STRING_POOL          = {} of String => ::Hecate::AST::Node
    private STRING_POOL_MUTEX    = Mutex.new
    private MAX_STRING_POOL_SIZE = 1000

    # Pool for common identifiers (variable names, keywords)
    private IDENTIFIER_POOL          = {} of String => ::Hecate::AST::Node
    private IDENTIFIER_POOL_MUTEX    = Mutex.new
    private MAX_IDENTIFIER_POOL_SIZE = 500

    # Statistics tracking
    @@pool_hits = 0_i64
    @@pool_misses = 0_i64
    @@stats_mutex = Mutex.new

    # Get or create a pooled integer literal
    def get_int_lit(span : Hecate::Core::Span, value : Int32, factory : Proc(Hecate::Core::Span, Int32, ::Hecate::AST::Node)) : ::Hecate::AST::Node
      # Only pool small integers (-128 to 127) - most commonly used range
      if -128 <= value <= 127
        INT_POOL_MUTEX.synchronize do
          if existing = INT_POOL[value]?
            record_hit
            existing
          else
            node = factory.call(span, value)
            INT_POOL[value] = node
            record_miss
            node
          end
        end
      else
        # Don't pool large integers - create directly
        record_miss
        factory.call(span, value)
      end
    end

    # Get or create a pooled boolean literal
    def get_bool_lit(span : Hecate::Core::Span, value : Bool, factory : Proc(Hecate::Core::Span, Bool, ::Hecate::AST::Node)) : ::Hecate::AST::Node
      BOOL_POOL_MUTEX.synchronize do
        if existing = BOOL_POOL[value]?
          record_hit
          existing
        else
          node = factory.call(span, value)
          BOOL_POOL[value] = node
          record_miss
          node
        end
      end
    end

    # Get or create a pooled string literal
    def get_string_lit(span : Hecate::Core::Span, value : String, factory : Proc(Hecate::Core::Span, String, ::Hecate::AST::Node)) : ::Hecate::AST::Node
      # Only pool strings up to reasonable length to avoid memory bloat
      if value.size <= 50 && STRING_POOL.size < MAX_STRING_POOL_SIZE
        STRING_POOL_MUTEX.synchronize do
          if existing = STRING_POOL[value]?
            record_hit
            existing
          else
            node = factory.call(span, value)
            if STRING_POOL.size < MAX_STRING_POOL_SIZE
              STRING_POOL[value] = node
            end
            record_miss
            node
          end
        end
      else
        # Don't pool long strings or when pool is full
        record_miss
        factory.call(span, value)
      end
    end

    # Get or create a pooled identifier
    def get_identifier(span : Hecate::Core::Span, name : String, factory : Proc(Hecate::Core::Span, String, ::Hecate::AST::Node)) : ::Hecate::AST::Node
      # Pool common identifier names (variables, keywords)
      if name.size <= 30 && IDENTIFIER_POOL.size < MAX_IDENTIFIER_POOL_SIZE
        IDENTIFIER_POOL_MUTEX.synchronize do
          if existing = IDENTIFIER_POOL[name]?
            record_hit
            existing
          else
            node = factory.call(span, name)
            if IDENTIFIER_POOL.size < MAX_IDENTIFIER_POOL_SIZE
              IDENTIFIER_POOL[name] = node
            end
            record_miss
            node
          end
        end
      else
        # Don't pool long names or when pool is full
        record_miss
        factory.call(span, name)
      end
    end

    # Pool statistics
    def pool_stats : NamedTuple(hits: Int64, misses: Int64, hit_rate: Float64,
      int_pool_size: Int32, bool_pool_size: Int32,
      string_pool_size: Int32, identifier_pool_size: Int32)
      @@stats_mutex.synchronize do
        total = @@pool_hits + @@pool_misses
        hit_rate = total > 0 ? (@@pool_hits.to_f / total * 100).round(2) : 0.0

        {
          hits:                 @@pool_hits,
          misses:               @@pool_misses,
          hit_rate:             hit_rate,
          int_pool_size:        INT_POOL.size,
          bool_pool_size:       BOOL_POOL.size,
          string_pool_size:     STRING_POOL.size,
          identifier_pool_size: IDENTIFIER_POOL.size,
        }
      end
    end

    # Clear all pools (for testing or memory management)
    def clear_pools
      INT_POOL_MUTEX.synchronize { INT_POOL.clear }
      BOOL_POOL_MUTEX.synchronize { BOOL_POOL.clear }
      STRING_POOL_MUTEX.synchronize { STRING_POOL.clear }
      IDENTIFIER_POOL_MUTEX.synchronize { IDENTIFIER_POOL.clear }
      @@stats_mutex.synchronize do
        @@pool_hits = 0_i64
        @@pool_misses = 0_i64
      end
    end

    # Get memory usage estimate of pools
    def pool_memory_estimate : NamedTuple(int_pool_bytes: Int32, bool_pool_bytes: Int32,
      string_pool_bytes: Int32, identifier_pool_bytes: Int32,
      total_bytes: Int32)
      int_bytes = INT_POOL.size * 96                # Rough estimate: 96 bytes per int node
      bool_bytes = BOOL_POOL.size * 92              # Slightly less for bool
      string_bytes = STRING_POOL.size * 120         # More for string storage
      identifier_bytes = IDENTIFIER_POOL.size * 110 # Similar to strings

      {
        int_pool_bytes:        int_bytes,
        bool_pool_bytes:       bool_bytes,
        string_pool_bytes:     string_bytes,
        identifier_pool_bytes: identifier_bytes,
        total_bytes:           int_bytes + bool_bytes + string_bytes + identifier_bytes,
      }
    end

    private def record_hit
      @@stats_mutex.synchronize { @@pool_hits += 1 }
    end

    private def record_miss
      @@stats_mutex.synchronize { @@pool_misses += 1 }
    end
  end
end
