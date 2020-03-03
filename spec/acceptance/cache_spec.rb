# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../support/dummy_store_implementation"

describe "Cache" do
  before do
    Rack::Attack.throttle("by ip", limit: 1, period: 60) do |request|
      request.ip
    end
  end

  it "fails when Rails.cache is not set" do
    Rails.cache = nil
    assert_raises(Rack::Attack::MissingStoreError) do
      get "/", {}, "REMOTE_ADDR" => "1.2.3.4"
    end
  end

  it "works when Rails.cache is set" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    get "/", {}, "REMOTE_ADDR" => "1.2.3.4"
    assert_equal 200, last_response.status

    get "/", {}, "REMOTE_ADDR" => "1.2.3.4"
    assert_equal 429, last_response.status
  end

  it "uses store adapter if available" do
    store_class = Class.new
    adapter_class = Class.new(Rack::Attack::StoreAdapter) do
      include DummyStoreImplementation
      define_singleton_method(:handle?) do |store|
        store.is_a?(store_class)
      end
    end

    Rack::Attack.cache.store = store_class.new
    assert_equal adapter_class, Rack::Attack.cache.store.class
  end

  it "uses store if adapter is not available" do
    store_class = Class.new { include DummyStoreImplementation }

    Rack::Attack.cache.store = store_class.new
    assert_equal store_class, Rack::Attack.cache.store.class
  end

  it "raises if store does not implement full required api" do
    store_class = Class.new
    assert_raises(Rack::Attack::MisconfiguredStoreError) do
      Rack::Attack.cache.store = store_class.new
    end
  end
end
