# frozen_string_literal: true

require_relative "../../spec_helper"
require_relative "../../support/cache_store_helper"

require "timecop"

describe "ActiveSupport::Cache::MemoryStore as a cache backend" do
  before do
    @store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store = @store
  end

  after do
    @store.clear
  end

  it_works_for_cache_backed_features(fetch_from_store: ->(key) { Rack::Attack.cache.store.fetch(key) })
end
