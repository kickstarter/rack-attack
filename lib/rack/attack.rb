require 'rack'
require 'forwardable'

class Rack::Attack
  autoload :Cache,           'rack/attack/cache'
  autoload :PathNormalizer,  'rack/attack/path_normalizer'
  autoload :Check,           'rack/attack/check'
  autoload :Throttle,        'rack/attack/throttle'
  autoload :Safelist,       'rack/attack/safelist'
  autoload :Blocklist,       'rack/attack/blocklist'
  autoload :Track,           'rack/attack/track'
  autoload :StoreProxy,      'rack/attack/store_proxy'
  autoload :DalliProxy,      'rack/attack/store_proxy/dalli_proxy'
  autoload :MemCacheProxy,   'rack/attack/store_proxy/mem_cache_proxy'
  autoload :RedisStoreProxy, 'rack/attack/store_proxy/redis_store_proxy'
  autoload :Fail2Ban,        'rack/attack/fail2ban'
  autoload :Allow2Ban,       'rack/attack/allow2ban'
  autoload :Request,         'rack/attack/request'

  class << self

    attr_accessor :notifier, :blocklisted_response, :throttled_response

    def safelist(name, &block)
      self.safelists[name] = Safelist.new(name, block)
    end

    def whitelist(name, &block)
      warn "[DEPRECATION] 'Rack::Attack.whitelist' is deprecated.  Please use 'safelist' instead."
      safelist(name, &block)
    end

    def blocklist(name, &block)
      self.blocklists[name] = Blocklist.new(name, block)
    end

    def blacklist(name, &block)
      warn "[DEPRECATION] 'Rack::Attack.blacklist' is deprecated.  Please use 'blocklist' instead."
      blocklist(name, &block)
    end

    def throttle(name, options, &block)
      self.throttles[name] = Throttle.new(name, options, block)
    end

    def track(name, options = {}, &block)
      self.tracks[name] = Track.new(name, options, block)
    end

    def safelists; @safelists ||= {}; end
    def blocklists; @blocklists ||= {}; end
    def throttles;  @throttles  ||= {}; end
    def tracks;     @tracks     ||= {}; end

    def whitelists
      warn "[DEPRECATION] 'Rack::Attack.whitelists' is deprecated.  Please use 'safelists' instead."
      safelists
    end

    def blacklists
      warn "[DEPRECATION] 'Rack::Attack.blacklists' is deprecated.  Please use 'blocklists' instead."
      blocklists
    end

    def safelisted?(req)
      safelists.any? do |name, safelist|
        safelist[req]
      end
    end

    def whitelisted?
      warn "[DEPRECATION] 'Rack::Attack.whitelisted?' is deprecated.  Please use 'safelisted?' instead."
      safelisted?
    end

    def blocklisted?(req)
      blocklists.any? do |name, blocklist|
        blocklist[req]
      end
    end

    def blacklisted?
      warn "[DEPRECATION] 'Rack::Attack.blacklisted?' is deprecated.  Please use 'blocklisted?' instead."
      blocklisted?
    end

    def throttled?(req)
      throttles.any? do |name, throttle|
        throttle[req]
      end
    end

    def tracked?(req)
      tracks.each_value do |tracker|
        tracker[req]
      end
    end

    def instrument(req)
      notifier.instrument('rack.attack', req) if notifier
    end

    def cache
      @cache ||= Cache.new
    end

    def clear!
      @safelists, @blocklists, @throttles, @tracks = {}, {}, {}, {}
    end

    def blacklisted_response=(res)
      warn "[DEPRECATION] 'Rack::Attack.blacklisted_response=' is deprecated.  Please use 'blocklisted_response=' instead."
      self.blocklisted_response=(res)
    end

    def blacklisted_response
      warn "[DEPRECATION] 'Rack::Attack.blacklisted_response' is deprecated.  Please use 'blocklisted_response' instead."
      self.blocklisted_response
    end

  end

  # Set defaults
  @notifier             = ActiveSupport::Notifications if defined?(ActiveSupport::Notifications)
  @blocklisted_response = lambda {|env| [403, {'Content-Type' => 'text/plain'}, ["Forbidden\n"]] }
  @throttled_response   = lambda {|env|
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    [429, {'Content-Type' => 'text/plain', 'Retry-After' => retry_after.to_s}, ["Retry later\n"]]
  }

  def initialize(app)
    @app = app
  end

  def call(env)
    env['PATH_INFO'] = PathNormalizer.normalize_path(env['PATH_INFO'])
    req = Rack::Attack::Request.new(env)

    response = case
      when safelisted?(req) then @app.call(env)
      when blocklisted?(req) then self.class.blocklisted_response.call(env)
      when throttled?(req) then self.class.throttled_response.call(env)
      else 
        tracked?(req)
        @app.call(env)
    end
    add_throttle_headers(response, env)
  end

  # always returns response object
  def add_throttle_headers(response, env)
    return response unless env['rack.attack.throttle_data']
    data = env['rack.attack.match_data'] || env['rack.attack.throttle_data']
    
    headers = case env["rack.attack.match_type"]
      when :throttle then throttle_headers(data)
      else
        # sort by number of remaining requests and time to expire if many throttles matched
        throttle_headers(
          data.values.sort_by {|data| [throttle_remaining(data), data[:expires_in]]}.first
        )
    end
    response[1].merge!(headers)
    response
  end
  
  def throttle_headers(data)
    {
      'X-RateLimit-Limit'       => data[:limit],
      'X-RateLimit-Remaining'   => throttle_remaining(data),
      'X-RateLimit-Reset'       => data[:expires_in]
    }
  end
  
  def throttle_remaining(data)
    dif = data[:limit] - data[:count]
    dif < 0 ? 0 : dif
  end
  
  extend Forwardable
  def_delegators self, :safelisted?,
                       :blocklisted?,
                       :throttled?,
                       :tracked?
end
