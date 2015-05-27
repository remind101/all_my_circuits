module AllMyCircuits
  module Strategies

    # Public: determines whether the circuit breaker should be tripped open
    # upon another error within the supplied block.
    #
    # See AllMyCircuits::Strategies::NumberWindowStrategy,
    # AllMyCircuits::Strategies::PercentageWindowStrategy for examples.
    #
    # To add a new strategy, subclass AllMyCircuits::Strategies::AbstractStrategy,
    # then register it:
    #
    #   class MyCustomStrategy < AllMyCircuits::Strategies::AbstractStrategy
    #     AllMyCircuits::Breaker::STRATEGIES[:my_custom_strategy] = self
    #   end
    #
    class AbstractStrategy
      def success
      end

      def error
      end

      def opened
      end

      def closed
      end

      def should_open?
        raise NotImplementedError
      end
    end

  end
end
