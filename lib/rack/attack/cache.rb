# frozen_string_literal: true

module Rack
  class Attack
    class Cache
      attr_accessor :prefix
      attr_reader :last_epoch_time

      def initialize
        self.store = ::Rails.cache if defined?(::Rails.cache)
        @prefix = 'rack::attack'
      end

      attr_reader :store
      def store=(store)
        raise Rack::Attack::MissingStoreError if store.nil?

        adapter = StoreAdapter.lookup(store)
        if adapter
          @store = adapter.new(store)
        elsif store?(store)
          @store = store
        else
          raise Rack::Attack::MisconfiguredStoreError
        end
      end

      def count(unprefixed_key, period)
        key, expires_in = key_and_expiry(unprefixed_key, period)
        do_count(key, expires_in)
      end

      def read(unprefixed_key)
        store.read("#{prefix}:#{unprefixed_key}")
      end

      def write(unprefixed_key, value, expires_in)
        store.write("#{prefix}:#{unprefixed_key}", value, expires_in: expires_in)
      end

      def reset_count(unprefixed_key, period)
        key, _ = key_and_expiry(unprefixed_key, period)
        store.delete(key)
      end

      def delete(unprefixed_key)
        store.delete("#{prefix}:#{unprefixed_key}")
      end

      def reset!
        if store.respond_to?(:delete_matched)
          store.delete_matched("#{prefix}*")
        else
          raise(
            Rack::Attack::IncompatibleStoreError,
            "Configured store #{store.class.name} doesn't respond to #delete_matched method"
          )
        end
      end

      private

      def key_and_expiry(unprefixed_key, period)
        @last_epoch_time = Time.now.to_i
        # Add 1 to expires_in to avoid timing error: https://git.io/i1PHXA
        expires_in = (period - (@last_epoch_time % period) + 1).to_i
        ["#{prefix}:#{(@last_epoch_time / period).to_i}:#{unprefixed_key}", expires_in]
      end

      def do_count(key, expires_in)
        result = store.increment(key, 1, expires_in: expires_in)

        # NB: Some stores return nil when incrementing uninitialized values
        if result.nil?
          store.write(key, 1, expires_in: expires_in)
        end
        result || 1
      end

      STORE_METHODS = [:read, :write, :increment, :delete].freeze

      def store?(object)
        STORE_METHODS.all? { |meth| object.respond_to?(meth) }
      end
    end
  end
end
