# frozen_string_literal: true

module Rack
  class Attack
    class Blocklist < Check
      def initialize(name = nil, &block)
        super
        @type = :blocklist
      end

      private

      def add_additional_matched_data(request)
        if (data = Thread.current[:rack_attack_matched_data])
          request.env["rack.attack.match_discriminator"] = data[:match_discriminator]
          Thread.current[:rack_attack_matched_data] = nil
        end
      end
    end
  end
end
