# frozen_string_literal: true

require 'rack/attack/store_adapter'

module Rack
  class Attack
    module StoreAdapters
      class ActiveSupportRedisStoreAdapter < StoreAdapter
        def self.handle?(store)
          defined?(::Redis) &&
            defined?(::ActiveSupport::Cache::RedisStore) &&
            store.is_a?(::ActiveSupport::Cache::RedisStore)
        end

        def read(key, options = {})
          store.read(key, options.merge!(raw: true))
        end

        def write(key, value, options = {})
          store.write(key, value, options.merge!(raw: true))
        end

        def increment(key, amount = 1, options = {})
          # #increment ignores options[:expires_in].
          #
          # So in order to workaround this we use #write (which sets expiration) to initialize
          # the counter. After that we continue using the original #increment.
          if options[:expires_in] && !read(key)
            write(key, amount, options)

            amount
          else
            store.increment(key, amount, options)
          end
        end

        def delete(key, options = {})
          store.delete(key, options)
        end

        def delete_matched(matcher, options = nil)
          store.delete_matched(matcher, options)
        end
      end
    end
  end
end
