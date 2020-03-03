# frozen_string_literal: true

require 'rack/attack/store_adapters/redis_adapter'

module Rack
  class Attack
    module StoreAdapters
      class RedisStoreAdapter < RedisAdapter
        def self.handle?(store)
          defined?(::Redis::Store) && store.is_a?(::Redis::Store)
        end

        def read(key)
          rescuing { store.get(key, raw: true) }
        end

        def write(key, value, options = {})
          if (expires_in = options[:expires_in])
            rescuing { store.setex(key, expires_in, value, raw: true) }
          else
            rescuing { store.set(key, value, raw: true) }
          end
        end
      end
    end
  end
end
