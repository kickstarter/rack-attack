# frozen_string_literal: true

require 'forwardable'

module Rack
  class Attack
    module StoreAdapters
      class MemCacheStoreAdapter < StoreAdapter
        def self.handle?(store)
          defined?(::Dalli) &&
            defined?(::ActiveSupport::Cache::MemCacheStore) &&
            store.is_a?(::ActiveSupport::Cache::MemCacheStore)
        end

        extend Forwardable
        def_delegators :@store, :read, :increment, :delete

        def write(key, value, options = {})
          store.write(key, value, options.merge!(raw: true))
        end
      end
    end
  end
end
