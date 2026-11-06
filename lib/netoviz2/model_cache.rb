# frozen_string_literal: true

module NetomoxExp
  module Netoviz2
    # Small LRU cache of models, keyed by the ETag of the topology file.
    #
    # Reading a large topology and building the model takes seconds and the clients request
    # summary/layers/supports/attributes one after another, so the model is kept until the file is updated.
    # (A model of a very large topology takes some hundreds of MB, so the number of entries is small.)
    class ModelCache
      DEFAULT_MAX_ENTRIES = 2

      # @param [Integer] max_entries Max number of models kept
      def initialize(max_entries = DEFAULT_MAX_ENTRIES)
        @max_entries = max_entries
        @entries = {}
        @mutex = Mutex.new
      end

      # @param [Array] key Cache key (e.g. [network, snapshot, etag])
      # @yield block to build a model when the key is not in the cache
      # @return [Model]
      def fetch_or_build(key)
        @mutex.synchronize do
          # NOTE: builds under the lock so that simultaneous requests do not build the same model twice
          model = @entries.delete(key) || yield
          @entries[key] = model # (re)insert as the most recently used
          @entries.shift while @entries.size > @max_entries
          model
        end
      end

      # @return [void]
      def clear
        @mutex.synchronize { @entries.clear }
      end

      # @return [Integer] number of cached models
      def size
        @mutex.synchronize { @entries.size }
      end
    end
  end
end
