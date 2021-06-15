# frozen_string_literal: true

module Rack
  class Attack
    class Throttle
      MANDATORY_OPTIONS = [:limit, :period].freeze

      attr_reader :name, :limit, :period, :weight, :block, :type

      def initialize(name, options, &block)
        @name = name
        @block = block
        MANDATORY_OPTIONS.each do |opt|
          raise ArgumentError, "Must pass #{opt.inspect} option" unless options[opt]
        end
        @limit = options[:limit]
        @period = options[:period].respond_to?(:call) ? options[:period] : options[:period].to_i
        @weight = options[:weight].respond_to?(:call) ? options[:weight] : (options[:weight] || 1).to_i
        @type   = options.fetch(:type, :throttle)
      end

      def cache
        Rack::Attack.cache
      end

      def matched_by?(request)
        discriminator = discriminator_for(request)
        return false unless discriminator

        current_period  = period_for(request)
        current_limit   = limit_for(request)
        current_weight  = weight_for(request)
        count           = cache.count("#{name}:#{discriminator}", current_period, current_weight)

        data = {
          discriminator: discriminator,
          count: count,
          period: current_period,
          limit: current_limit,
          epoch_time: cache.last_epoch_time
        }

        (count > current_limit).tap do |throttled|
          annotate_request_with_throttle_data(request, data)
          if throttled
            annotate_request_with_matched_data(request, data)
            Rack::Attack.instrument(request)
          end
        end
      end

      private

      def discriminator_for(request)
        discriminator = block.call(request)
        if discriminator && Rack::Attack.throttle_discriminator_normalizer
          discriminator = Rack::Attack.throttle_discriminator_normalizer.call(discriminator)
        end
        discriminator
      end

      def period_for(request)
        period.respond_to?(:call) ? period.call(request) : period
      end

      def limit_for(request)
        limit.respond_to?(:call) ? limit.call(request) : limit
      end

      def weight_for(request)
        weight.respond_to?(:call) ? weight.call(request) : weight
      end

      def annotate_request_with_throttle_data(request, data)
        (request.env['rack.attack.throttle_data'] ||= {})[name] = data
      end

      def annotate_request_with_matched_data(request, data)
        request.env['rack.attack.matched']             = name
        request.env['rack.attack.match_discriminator'] = data[:discriminator]
        request.env['rack.attack.match_type']          = type
        request.env['rack.attack.match_data']          = data
      end
    end
  end
end
