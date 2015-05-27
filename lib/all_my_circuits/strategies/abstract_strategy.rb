module AllMyCircuits
  module Strategies

    # Public: determines whether the circuit breaker should be tripped open
    # upon another error within the supplied block.
    #
    # See AllMyCircuits::Strategies::NumberOverWindowStrategy,
    # AllMyCircuits::Strategies::PercentageOverWindowStrategy for examples.
    #
    class AbstractStrategy

      # Public: called whenever a request has ran successfully through circuit breaker.
      #
      def success
      end

      # Public: called whenever a request has failed within circuit breaker.
      #
      def error
      end

      # Public: called whenever circuit is tripped open.
      #
      def opened
      end

      # Public: called whenever circuit is closed.
      #
      def closed
      end

      # Public: called after each error within circuit breaker to determine
      # whether it should be tripped open.
      #
      def should_open?
        raise NotImplementedError
      end
    end

  end
end
