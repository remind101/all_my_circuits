require "concurrent/atomic"

module AllMyCircuits

  class Breaker
    # Extend this dictionary to add more strategies
    #
    STRATEGIES = {
      nil                     => Strategies::PercentageWindowStrategy,
      :percentage_over_window => Strategies::PercentageWindowStrategy,
      :number_over_window     => Strategies::NumberWindowStrategy
    }

    def initialize(name:, strategy:)
      @name = name.dup

      begin
        strategy_name = strategy.delete(:name)
        @strategy = STRATEGIES.fetch(strategy_name).new(**strategy)
        @request_number = Concurrent::Atomic.new(0)
      rescue KeyError
        raise ArgumentError, "Unknown circuit breaker strategy: #{strategy_name}"
      end
    end

    def run
      unless @strategy.allow_request?
        raise BreakerOpen, @name
      end

      current_request_number = @request_number.update { |v| v + 1 }

      begin
        yield
        @strategy.success(current_request_number, @request_number.value)
      rescue
        @strategy.error(current_request_number, @request_number.value)
        raise
      end
    end
  end

end
