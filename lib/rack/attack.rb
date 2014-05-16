require 'rack'
require 'forwardable'

class Rack::Attack
  autoload :Cache,           'rack/attack/cache'
  autoload :Check,           'rack/attack/check'
  autoload :Throttle,        'rack/attack/throttle'
  autoload :Whitelist,       'rack/attack/whitelist'
  autoload :Blacklist,       'rack/attack/blacklist'
  autoload :Track,           'rack/attack/track'
  autoload :Meter,           'rack/attack/meter'
  autoload :StoreProxy,      'rack/attack/store_proxy'
  autoload :DalliProxy,      'rack/attack/store_proxy/dalli_proxy'
  autoload :RedisStoreProxy, 'rack/attack/store_proxy/redis_store_proxy'
  autoload :Fail2Ban,        'rack/attack/fail2ban'
  autoload :Allow2Ban,       'rack/attack/allow2ban'
  autoload :Request,         'rack/attack/request'

  class << self

    attr_accessor :notifier, :blacklisted_response, :throttled_response

    def whitelist(name, &block)
      self.whitelists[name] = Whitelist.new(name, block)
    end

    def blacklist(name, &block)
      self.blacklists[name] = Blacklist.new(name, block)
    end

    def throttle(name, options, &block)
      self.throttles[name] = Throttle.new(name, options, block)
    end

    def track(name, &block)
      self.tracks[name] = Track.new(name, block)
    end

    def meter(name, options, &block)
      self.meters[name] = Meter.new(name, options, block)
    end

    def whitelists; @whitelists ||= {}; end
    def blacklists; @blacklists ||= {}; end
    def throttles;  @throttles  ||= {}; end
    def tracks;     @tracks     ||= {}; end
    def meters;     @meters     ||= {}; end

    def whitelisted?(req)
      whitelists.any? do |name, whitelist|
        whitelist[req]
      end
    end

    def blacklisted?(req)
      blacklists.any? do |name, blacklist|
        blacklist[req]
      end
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

    def metered?(req)
      meters.any? do |name, meter|
        meter[req]
      end
    end

    def instrument(req)
      notifier.instrument('rack.attack', req) if notifier
    end

    def cache
      @cache ||= Cache.new
    end

    def clear!
      @whitelists, @blacklists, @throttles, @meters = {}, {}, {}, {}
    end

  end

  # Set defaults
  @notifier             = ActiveSupport::Notifications if defined?(ActiveSupport::Notifications)
  @blacklisted_response = lambda {|env| [403, {}, ["Forbidden\n"]] }
  @throttled_response   = lambda {|env|
    retry_after = env['rack.attack.match_data'][:period] rescue nil
    [429, {'Retry-After' => retry_after.to_s}, ["Retry later\n"]]
  }

  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Attack::Request.new(env)

    if whitelisted?(req)
      @app.call(env)
    elsif blacklisted?(req)
      self.class.blacklisted_response[env]
    elsif throttled?(req)
      self.class.throttled_response[env]
    elsif metered?(req)
      @app.call(env)
    else
      tracked?(req)
      @app.call(env)
    end
  end

  extend Forwardable
  def_delegators self, :whitelisted?,
                       :blacklisted?,
                       :throttled?,
                       :tracked?,
                       :metered?
end
