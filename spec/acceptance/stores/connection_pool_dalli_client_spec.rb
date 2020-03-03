# frozen_string_literal: true

require_relative "../../spec_helper"

if defined?(::Dalli) && defined?(::ConnectionPool)
  require_relative "../../support/cache_store_helper"
  require "connection_pool"
  require "dalli"
  require "timecop"

  describe "ConnectionPool with Dalli::Client as a cache backend" do
    before do
      @store = ConnectionPool.new { Dalli::Client.new }
      Rack::Attack.cache.store = @store
    end

    after do
      @store.with { |client| client.flush_all }
    end

    it_works_for_cache_backed_features(
      fetch_from_store: ->(key) { Dalli::Client.new.get(key) }
    )
  end
end
