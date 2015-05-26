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

    # Public: Initializes circuit breaker instance.
    #
    # Options
    #
    #   name     - name of the call wrapped into circuit breaker (e.g. "That Unstable Service").
    #   strategy - a hash with circuit breaker behavior config; varies per strategy.
    #              Available strategies: :percentage_over_window (default), :number_over_window.
    #
    # Examples
    #
    #   AllMyCircuits::Breaker.new(
    #     "My Unstable Service",
    #     strategy: {
    #       name: :percentage_over_window,
    #       requests_window: 20,                 # number of requests in the window to calculate failure rate for
    #       sleep_seconds: 5,                    # how long should the circuit stay open
    #       failure_rate_percent_threshold: 25   # how many failures can occur within the window, in percent,
    #     }                                      #   before the circuit opens
    #   )
    #
    #   AllMyCircuits::Breaker.new(
    #     "Another Unstable Service",
    #     strategy: {
    #       name: :number_over_window,
    #       requests_window: 20,
    #       sleep_seconds: 5,
    #       failures_threshold: 25         # how many failures can occur within the window before the circuit opens
    #     }
    #   )
    #
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

    # Public: executes supplied block of code and monitors failures.
    # Once the number of failures reaches a certain threshold, the block is bypassed
    # for a certain period of time.
    #
    # Consider the following examples of calls through circuit breaker (let it be 1 call per second,
    # and let the circuit breaker be configured as in the example below):
    #
    # Legend
    #
    #   S - successful request
    #   F - failed request
    #   O - skipped request (circuit open)
    #   | - open circuit interval end
    #
    #
    #   1) S S F F S S F F S F O O O O O|S S S S S
    #
    #   Here among the first 10 requests (window), 5 failures occur (50%), the circuit is tripped open
    #   for 5 seconds, and a few requests are skipped. Then, after 5 seconds, a request is issued to
    #   see whether everything is back to normal, and the circuit is then closed again.
    #
    #   2) S S F F S S F F S F O O O O O|F O O O O O|S S S S S
    #
    #   Same situation, 10 requests, 5 failed, circuit is tripped open for 5 seconds. Then we
    #   check that service is back to normal, and it is not. The circuit is open again.
    #   After another 5 seconds we check again and close the circuit.
    #
    # Returns nothing.
    # Raises AllMyCircuit::BreakerOpen with the name of the service when the circuit is open.
    # Raises whatever has been raised by the supplied block.
    #
    # This call is thread-safe sans the supplied block.
    #
    # Examples
    #
    #   @cb = AllMyCircuits::Breaker.new(
    #     "that bad service",
    #     strategy: {
    #       name: :percentage_over_window,
    #       requests_window: 10,
    #       failure_rate_percent_threshold: 50,
    #       sleep_seconds: 5,
    #     }
    #   )
    #
    #   @client = MyBadServiceClient.new(timeout: 2)
    #
    #   begin
    #     @cb.run do
    #       @client.make_expensive_unreliable_http_call
    #     end
    #   rescue AllMyCircuits::BreakerOpen => e
    #     []
    #   rescue MyBadServiceClient::Error => e
    #     MyLog << "an error has occured in call to my bad service"
    #     []
    #   end
    #
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
