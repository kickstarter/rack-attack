# frozen_string_literal: true

require_relative "../../spec_helper"

if defined?(::ActiveSupport::Cache::RedisStore)
  require_relative "../../support/cache_store_helper"
  require "timecop"

  describe "ActiveSupport::Cache::RedisStore as a cache backend" do
    before do
      @store = ActiveSupport::Cache::RedisStore.new
      Rack::Attack.cache.store = @store
    end

    after do
      @store.clear
    end

    it_works_for_cache_backed_features(fetch_from_store: ->(key) { Rack::Attack.cache.store.read(key) })
  end
end
