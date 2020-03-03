# frozen_string_literal: true

require_relative "../../spec_helper"

if defined?(::Redis)
  require_relative "../../support/cache_store_helper"
  require "timecop"

  describe "Plain redis as a cache backend" do
    before do
      @store = Redis.new
      Rack::Attack.cache.store = @store
    end

    after do
      @store.flushdb
    end

    it_works_for_cache_backed_features(fetch_from_store: ->(key) { Rack::Attack.cache.store.read(key) })
  end
end
