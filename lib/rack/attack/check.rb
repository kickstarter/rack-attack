module Rack
  class Attack
    class Check
      attr_reader :name, :block, :type
      def initialize(name, options = {}, &block)
        raise ArgumentError.new(format(Rack::Attack::ERROR_MESSAGE, name)) unless Kernel.block_given?
        @name, @block = name, block
        @type = options.fetch(:type, nil)
      end

      def [](req)
        block[req].tap {|match|
          if match
            req.env["rack.attack.matched"] = name
            req.env["rack.attack.match_type"] = type
            Rack::Attack.instrument(req)
          end
        }
      end

    end
  end
end
