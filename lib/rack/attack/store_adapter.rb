# frozen_string_literal: true

module Rack
  class Attack
    class StoreAdapter
      class << self
        def adapters
          @@adapters ||= []
        end

        def inherited(klass)
          adapters << klass
        end

        def lookup(store)
          adapters.find { |adapter| adapter.handle?(store) }
        end

        def handle?(store)
          raise NotImplementedError
        end
      end

      attr_reader :store

      def initialize(store)
        @store = store
      end

      def read(key)
        raise NotImplementedError
      end

      def write(key, value, options = {})
        raise NotImplementedError
      end

      def increment(key, amount, options = {})
        raise NotImplementedError
      end

      def delete(key, options = {})
        raise NotImplementedError
      end
    end
  end
end
