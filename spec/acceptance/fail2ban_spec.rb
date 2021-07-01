# frozen_string_literal: true

require_relative "../spec_helper"
require "timecop"

describe "fail2ban" do
  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    Rack::Attack.blocklist("fail2ban pentesters") do |request|
      Rack::Attack::Fail2Ban.filter(request.ip, maxretry: 2, findtime: 30, bantime: 60) do
        request.path.include?("private-place")
      end
    end
  end

  it "returns OK for many requests to non filtered path" do
    get "/"
    assert_equal 200, last_response.status

    get "/"
    assert_equal 200, last_response.status
  end

  it "forbids access to private path" do
    get "/private-place"
    assert_equal 403, last_response.status
  end

  it "returns OK for non filtered path if yet not reached maxretry limit" do
    get "/private-place"
    assert_equal 403, last_response.status

    get "/"
    assert_equal 200, last_response.status
  end

  it "forbids all access after reaching maxretry limit" do
    get "/private-place"
    assert_equal 403, last_response.status

    get "/private-place"
    assert_equal 403, last_response.status

    get "/"
    assert_equal 403, last_response.status
  end

  it "restores access after bantime elapsed" do
    get "/private-place"
    assert_equal 403, last_response.status

    get "/private-place"
    assert_equal 403, last_response.status

    get "/"
    assert_equal 403, last_response.status

    Timecop.travel(60) do
      get "/"

      assert_equal 200, last_response.status
    end
  end

  it "does not forbid all access if maxrety condition is met but not within the findtime timespan" do
    get "/private-place"
    assert_equal 403, last_response.status

    Timecop.travel(31) do
      get "/private-place"
      assert_equal 403, last_response.status

      get "/"
      assert_equal 200, last_response.status
    end
  end

  it "notifies when the request is blocked" do
    notification_matched = nil
    notification_type = nil
    notification_discriminator = nil

    ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _id, payload|
      notification_matched = payload[:request].env["rack.attack.matched"]
      notification_type = payload[:request].env["rack.attack.match_type"]
      notification_discriminator = payload[:request].env["rack.attack.match_discriminator"]
    end

    2.times { get "/private-place", {}, "REMOTE_ADDR" => "1.2.3.4" }

    assert_equal "fail2ban pentesters", notification_matched
    assert_equal :blocklist, notification_type
    assert_equal "1.2.3.4", notification_discriminator
  end
end
