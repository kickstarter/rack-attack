# frozen_string_literal: true

require 'rack/attack/store_adapter'

module Rack
  class Attack
    module StoreAdapters
      class RedisCacheStoreAdapter < StoreAdapter
        def self.handle?(store)
          store.class.name == "ActiveSupport::Cache::RedisCacheStore"
        end

        def read(*args)
          rescuing { store.read(*args) }
        end

        def write(key, value, options = {})
          rescuing do
            store.write(key, value, options.merge!(raw: true))
          end
        end

        def increment(key, amount = 1, options = {})
          # RedisCacheStore#increment ignores options[:expires_in].
          #
          # So in order to workaround this we use RedisCacheStore#write (which sets expiration) to initialize
          # the counter. After that we continue using the original RedisCacheStore#increment.
          rescuing do
            if options[:expires_in] && !read(key)
              write(key, amount, options)

              amount
            else
              store.increment(key, amount, options)
            end
          end
        end

        def delete(*args)
          rescuing { store.delete(*args) }
        end

        def delete_matched(matcher, options = nil)
          store.delete_matched(matcher, options)
        end

        private

        def rescuing
          yield
        rescue Redis::BaseConnectionError
          nil
        end
      end
    end
  end
end
