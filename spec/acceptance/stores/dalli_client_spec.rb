# frozen_string_literal: true

require_relative "../../spec_helper"

if defined?(::Dalli)
  require_relative "../../support/cache_store_helper"
  require "dalli"
  require "timecop"

  describe "Dalli::Client as a cache backend" do
    before do
      @client = Dalli::Client.new
      Rack::Attack.cache.store = @client
    end

    after do
      @client.flush_all
    end

    it_works_for_cache_backed_features(fetch_from_store: ->(key) { Rack::Attack.cache.store.read(key) })
  end
end
