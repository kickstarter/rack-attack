require 'delegate'

module Rack
  class Attack
    module StoreProxy
      class RedisCacheStoreProxy < SimpleDelegator
        def self.handle?(store)
          defined?(::ActiveSupport::Cache::RedisCacheStore) && store.is_a?(::ActiveSupport::Cache::RedisCacheStore)
        end

        def increment(name, amount, options = {})
          # Redis doesn't check expiration on the INCRBY command. See https://redis.io/commands/expire
          redis.with do |r|
            count = r.pipelined do
              r.incrby(name, amount)
              r.expire(name, options[:expires_in]) if options[:expires_in]
            end
            count.first
          end
        end

        def read(name, options = {})
          super(name, options.merge!(raw: true))
        end

        def write(name, value, options = {})
          super(name, value, options.merge!(raw: true))
        end
      end
    end
  end
end
