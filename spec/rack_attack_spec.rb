require_relative 'spec_helper'

describe 'Rack::Attack' do
  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  allow_ok_requests

  describe 'normalizing paths' do
    before do
      Rack::Attack.blocklist("banned_path") {|req| req.path == '/foo' }
    end

    it 'blocks requests with trailing slash' do
      get '/foo/'
      last_response.status.must_equal 403
    end
  end

  describe 'blocklist' do
    before do
      @bad_ip = '1.2.3.4'
      Rack::Attack.blocklist("ip #{@bad_ip}") {|req| req.ip == @bad_ip }
    end

    it('has a blocklist') {
      Rack::Attack.blocklists.key?("ip #{@bad_ip}").must_equal true
    }

    it('has a blacklist with a deprication warning') {
      _, stderror  = capture_io do
        Rack::Attack.blacklists.key?("ip #{@bad_ip}").must_equal true
      end
      assert_match "[DEPRECATION] 'Rack::Attack.blacklists' is deprecated.  Please use 'blocklists' instead.", stderror
    }

    describe "a bad request" do
      before { get '/', {}, 'REMOTE_ADDR' => @bad_ip }
      it "should return a blocklist response" do
        get '/', {}, 'REMOTE_ADDR' => @bad_ip
        last_response.status.must_equal 403
        last_response.body.must_equal "Forbidden\n"
      end
      it "should tag the env" do
        last_request.env['rack.attack.matched'].must_equal "ip #{@bad_ip}"
        last_request.env['rack.attack.match_type'].must_equal :blocklist
      end

      describe "with a custom blocklisted response" do
        before do
          Rack::Attack.blocklisted_response = lambda {|env|
            [418, {'Content-Type' => 'text/plain'}, ["I'm a teapot\n"]]
          }

          Rack::Attack.set_named_blocklisted_response("geoblocked", lambda {|env|
            [451, {'Content-Type' => 'text/plain'}, ["lawyer says no\n"]]
          })

          @banstralia_ip = '61.2.3.4'
          Rack::Attack.blocklist("geoblocked") {|req| req.ip == @banstralia_ip }
        end

        describe "when no named responses match" do
          it "should return a custom blocklist response" do
            get '/', {}, 'REMOTE_ADDR' => @bad_ip
            last_response.status.must_equal 418
            last_response.body.must_equal "I'm a teapot\n"
          end
        end

        describe "when a named response does match" do
          it "should return a custom blocklist response" do
            get '/', {}, 'REMOTE_ADDR' => @banstralia_ip
            last_response.status.must_equal 451
            last_response.body.must_equal "lawyer says no\n"
          end
        end
      end

      allow_ok_requests
    end

    describe "and safelist" do
      before do
        @good_ua = 'GoodUA'
        Rack::Attack.safelist("good ua") {|req| req.user_agent == @good_ua }
      end

      it('has a safelist'){ Rack::Attack.safelists.key?("good ua") }

      it('has a whitelist with a deprication warning') {
        _, stderror  = capture_io do
          Rack::Attack.whitelists.key?("good ua")
        end
        assert_match "[DEPRECATION] 'Rack::Attack.whitelists' is deprecated.  Please use 'safelists' instead.", stderror
      }

      describe "with a request match both safelist & blocklist" do
        before { get '/', {}, 'REMOTE_ADDR' => @bad_ip, 'HTTP_USER_AGENT' => @good_ua }
        it "should allow safelists before blocklists" do
          get '/', {}, 'REMOTE_ADDR' => @bad_ip, 'HTTP_USER_AGENT' => @good_ua
          last_response.status.must_equal 200
        end
        it "should tag the env" do
          last_request.env['rack.attack.matched'].must_equal 'good ua'
          last_request.env['rack.attack.match_type'].must_equal :safelist
        end
      end
    end
  end

  describe 'throttle' do
    before do
      Rack::Attack.throttle("too fast", limit: 4, period: 60) {|req| req.ip }
    end

    it('has a throttle') {
      Rack::Attack.throttles.key?("too fast").must_equal true
    }

    describe "throttled request" do
      before do
        @fast_ip = '1.2.3.4'
        @furious_ip  = '2.3.4.5'
        4.times { get '/', {}, 'REMOTE_ADDR' => @fast_ip }
      end

      it "should return a throttled response" do
        get '/', {}, 'REMOTE_ADDR' => @fast_ip
        last_response.status.must_equal 429
        last_response.body.must_equal "Retry later\n"
        last_response.headers["Retry-After"].must_equal "60"
      end
      it "should tag the env" do
        get '/', {}, 'REMOTE_ADDR' => @fast_ip
        last_request.env['rack.attack.matched'].must_equal "too fast"
        last_request.env['rack.attack.match_type'].must_equal :throttle
      end

      describe "with a custom throttled response" do
        before do
          Rack::Attack.throttled_response = lambda {|env|
            [418, {'Content-Type' => 'text/plain'}, ["I'm a teapot\n"]]
          }

          Rack::Attack.set_named_throttled_response("too furious", lambda {|env|
            [420, {'Content-Type' => 'text/plain'}, ["enhance your calm\n"]]
          })

          Rack::Attack.throttle("too furious", limit: 2, period: 60) do |req|
            req.ip if req.post?
          end
        end

        describe "when no named responses match" do
          it "should return a custom blocklist response" do
            get '/', {}, 'REMOTE_ADDR' => @fast_ip
            last_response.status.must_equal 418
            last_response.body.must_equal "I'm a teapot\n"
          end
        end

        describe "when a named response does match" do
          before { 2.times { post '/', {}, 'REMOTE_ADDR' => @furious_ip } }
          it "should return a custom blocklist response" do
            post '/', {}, 'REMOTE_ADDR' => @furious_ip
            last_response.status.must_equal 420
            last_response.body.must_equal "enhance your calm\n"
          end
        end
      end

      allow_ok_requests
    end

    describe "and safelist" do
      before do
        @good_ua = 'GoodUA'
        @fast_ip = '1.2.3.4'
        Rack::Attack.safelist("good ua") {|req| req.user_agent == @good_ua }
      end

      it('has a safelist'){ Rack::Attack.safelists.key?("good ua") }

      describe "with a request match both safelist & throttled" do
        before do
          10.times { get '/', {}, 'REMOTE_ADDR' => @fast_ip, 'HTTP_USER_AGENT' => @good_ua }
        end

        it "should allow safelists before blocklists" do
          get '/', {}, 'REMOTE_ADDR' => @fast_ip, 'HTTP_USER_AGENT' => @good_ua
          last_response.status.must_equal 200
        end
        it "should tag the env" do
          last_request.env['rack.attack.matched'].must_equal 'good ua'
          last_request.env['rack.attack.match_type'].must_equal :safelist
        end
      end
    end
  end

  describe '#blocklisted_response' do
    it 'should exist' do
      Rack::Attack.blocklisted_response.must_respond_to :call
    end

    it 'should give a deprication warning for blacklisted_response' do
      _, stderror  = capture_io do
        Rack::Attack.blacklisted_response
      end
      assert_match "[DEPRECATION] 'Rack::Attack.blacklisted_response' is deprecated.  Please use 'blocklisted_response' instead.", stderror

    end
  end

  describe '#throttled_response' do
    it 'should exist' do
      Rack::Attack.throttled_response.must_respond_to :call
    end
  end
end
