# frozen_string_literal: true

module Rack
  class Attack
    class ResponseHeaders
      # Attributes
      attr_reader :count, :epoch_time, :limit, :period

      def initialize(data)
        @count = data[:count]
        @epoch_time = data[:epoch_time]
        @limit = data[:limit]
        @period = data[:period]
      end

      # Access the epoch time as a time object.
      #
      # @return [Time]
      def count_time
        @count_time ||= Time.zone.at(epoch_time, in: 'UTC')
      end

      # Generate rate limit headers.
      #
      # @param include_limit [Boolean] - whethert to include the `X-RateLimit-Limit` header.
      # @param include_remaining [Boolean] - whethert to include the `X-RateLimit-Remaining` header.
      # @param include_reset [Boolean] - whethert to include the `X-RateLimit-Reset` header.
      #
      # @return [Hash]
      def generate(include_limit: true, include_remaining: true, include_reset: true)
        headers = {}
        headers['X-RateLimit-Limit'] = limit.to_s if include_limit
        headers['X-RateLimit-Remaining'] = remaining.to_s if include_remaining
        headers['X-RateLimit-Reset'] = reset.iso8601 if include_reset
        headers
      end

      # Calculate the number of requests remaining in the current rate limit
      # window.
      #
      # @return [Integer]
      def remaining
        @remaining ||= limit - count
      end

      # Calculate the time at which the current rate limit window resets in UTC.
      # https://github.com/rack/rack-attack/pull/191#issuecomment-237295523
      #
      # @return [Time]
      def reset
        @reset ||= count_time + (period - count_time.to_i % period)
      end
    end
  end
end
