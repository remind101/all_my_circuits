require 'concurrent/atomics'
require "thread"

module AllMyCircuits

  class Breaker
    include Logging

    attr_reader :name

    # Public: exceptions typically thrown when using Net::HTTP
    #
    def self.net_errors
      require "timeout"
      require "net/http"

      [
        EOFError,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Errno::ETIMEDOUT,
        IOError,
        Net::HTTPBadResponse,
        Net::HTTPFatalError,
        Net::HTTPHeaderSyntaxError,
        Net::HTTPBadGateway,
        Net::HTTPServiceUnavailable,
        Net::HTTPGatewayTimeOut,
        Net::ProtocolError,
        SocketError,
        Timeout::Error
      ]
    end


    # Public: Initializes circuit breaker instance.
    #
    # Options
    #
    #   name          - name of the call wrapped into circuit breaker (e.g. "That Unstable Service").
    #   watch_errors  - exceptions to count as failures. Other exceptions will simply get re-raised
    #                   (default: AllMyCircuits::Breaker.net_errors).
    #   sleep_seconds - number of seconds the circuit stays open before attempting to close.
    #                   If given an object that responds to #call, it will call #call with the number
    #                   of times this circuit has been open consecutively. This can be used to exponentially
    #                   backoff.
    #   strategy      - an AllMyCircuits::Strategies::AbstractStrategy-compliant object that controls
    #                   when the circuit should be tripped open.
    #                   Built-in strategies:
    #                     AllMyCircuits::Strategies::PercentageOverWindowStrategy,
    #                     AllMyCircuits::Strategies::NumberOverWindowStrategy.
    #   notifier      - (optional) AllMyCircuits::Notifiers::AbstractNotifier-compliant object that
    #                   is called whenever circuit breaker state (open, closed) changes.
    #                   Built-in notifiers:
    #                     AllMyCircuits::Notifiers::NullNotifier.
    #
    # Examples
    #
    #   AllMyCircuits::Breaker.new(
    #     name: "My Unstable Service",
    #     sleep_seconds: 5,
    #     strategy: AllMyCircuits::Strategies::PercentageOverWindowStrategy.new(
    #       requests_window: 20,                 # number of requests in the window to calculate failure rate for
    #       failure_rate_percent_threshold: 25   # how many failures can occur within the window, in percent,
    #     )                                      #   before the circuit opens
    #   )
    #
    #   AllMyCircuits::Breaker.new(
    #     name: "Another Unstable Service",
    #     sleep_seconds: 5,
    #     strategy: AllMyCircuits::Strategies::NumberOverWindowStrategy.new(
    #       requests_window: 20,
    #       failures_threshold: 25         # how many failures can occur within the window before the circuit opens
    #     )
    #   )
    #
    def initialize(name:,
                   watch_errors: Breaker.net_errors,
                   sleep_seconds:,
                   strategy:,
                   notifier: Notifiers::NullNotifier.new,
                   clock: Clock)

      @name = String(name).dup.freeze
      @watch_errors = Array(watch_errors).dup

      if sleep_seconds.respond_to?(:call)
        @timeout = sleep_seconds
      else
        @timeout = proc { sleep_seconds }
      end

      @strategy = strategy
      @notifier = notifier

      @state_lock = Mutex.new
      @request_number = Concurrent::AtomicReference.new(0)
      @last_open_or_probed = nil
      @probe_count = 0
      @opened_at_request_number = 0
      @clock = clock
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
    #     name: "that bad service",
    #     sleep_seconds: 5,
    #     strategy: AllMyCircuits::Strategies::PercentageOverWindowStrategy.new(
    #       requests_window: 10,
    #       failure_rate_percent_threshold: 50
    #     )
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
      unless allow_request?
        debug "declining request, circuit is open", name
        raise BreakerOpen, @name
      end

      current_request_number = generate_request_number
      begin
        result = yield
        success(current_request_number)
        result
      rescue *@watch_errors
        error(current_request_number)
        raise
      end
    end

    private

    # Internal: checks whether the circuit is closed, or if it is time
    # to try one request to see if things are back to normal.
    #
    def allow_request?
      @state_lock.synchronize do
        !open? || allow_probe_request?
      end
    end

    def generate_request_number
      current_request_number = @request_number.update { |v| v + 1 }

      debug "new request", name, current_request_number
      current_request_number
    end

    # Internal: marks request as successful. Closes the circuit if necessary.
    #
    # Arguments
    #   current_request_number - the number assigned to the request by the circuit breaker
    #                            before it was sent.
    #
    def success(current_request_number)
      will_notify_notifier_closed = false

      @state_lock.synchronize do
        if open?
          # This ensures that we are not closing the circuit prematurely
          # due to a response for an old request coming in.
          if current_request_number > @opened_at_request_number
            info "closing circuit", name, current_request_number
            close!
            will_notify_notifier_closed = true
          else
            debug "ignoring late success response", name, current_request_number
          end
        end
        debug "request succeeded", name, current_request_number
        @strategy.success
      end

      # We don't want to be doing this while holding the lock
      if will_notify_notifier_closed
        @notifier.closed
      end
    end

    # Internal: marks request as failed. Opens the circuit if necessary.
    #
    def error(current_request_number)
      will_notify_notifier_opened = false

      @state_lock.synchronize do
        if open?
          debug "ignoring late error response (circuit is open)", name, current_request_number
          return
        end

        debug "request failed. #{@strategy.inspect}", name, current_request_number
        @strategy.error

        if @strategy.should_open?
          info "opening circuit", name, current_request_number
          open!
          will_notify_notifier_opened = true
        end
      end

      # We don't want to be doing this while holding the lock
      if will_notify_notifier_opened
        @notifier.opened
      end
    end

    def open?
      @opened_at_request_number > 0
    end

    def breaker_expired?
      seconds = @timeout.call(@probe_count + 1)
      @clock.timestamp >= (@last_open_or_probed + seconds)
    end

    def allow_probe_request?
      if open? && breaker_expired?
        debug "allowing probe request", name
        # makes sure that we allow only one probe request by extending sleep interval
        # and leaving the circuit open until closed by the success callback.
        @last_open_or_probed = @clock.timestamp
        @probe_count += 1
        return true
      end
      false
    end

    def open!
      @last_open_or_probed = @clock.timestamp
      # The most recent request encountered so far (may not be the current request in concurrent situation).
      # This is necessary to prevent successful response to old request from opening the circuit prematurely.
      # Imagine concurrent situation ("|" for request start, ">" for request end):
      #   1|-----------> success
      #     2|----> error, open circuit breaker
      # In this case request 1) should not close the circuit.
      @opened_at_request_number = @request_number.value
      @strategy.opened
    end

    def close!
      @last_open_or_probed = 0
      @probe_count = 0
      @opened_at_request_number = 0
      @strategy.closed
    end
  end

end
