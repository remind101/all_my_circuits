require "thread"

module AllMyCircuits
  module Strategies

    class AbstractWindowStrategy
      autoload :Window, "all_my_circuits/strategies/abstract_window_strategy/window"

      def initialize(requests_window:, sleep_seconds:, clock: Clock)
        @requests_window = requests_window
        @sleep_seconds = sleep_seconds
        @clock = clock

        @last_open_or_probed = nil
        @opened_at_request_number = 0

        @window = Window.new(@requests_window)

        @state_mtx = Mutex.new
      end

      # Internal: checks whether the circuit is closed, or if it is time
      # to try one request to see if things are back to normal.
      #
      def allow_request?
        @state_mtx.synchronize do
          !open? || allow_probe_request?
        end
      end

      # Internal: marks request as successful.
      #
      # Arguments
      #   current_request_number - the number assigned to the request by the circuit breaker
      #                            before it was sent.
      #
      def success(current_request_number, _)
        @state_mtx.synchronize do
          # This ensures that we are not closing the circuit prematurely
          # due to a response for an old request coming in.
          if open? && current_request_number > @opened_at_request_number
            @last_open_or_probed = 0
            @opened_at_request_number = 0
            @window.reset!
          end
          @window << :succeeded
        end
      end

      # Internal: marks request as failed.
      #
      # Arguments
      #   most_recent_request_number - the number of the most recent request being processed
      #                                (not necessarily the request for which this callback is
      #                                triggered now in concurrent situation.)
      #
      def error(_, most_recent_request_number)
        @state_mtx.synchronize do
          unless open?
            @window << :failed
            if @window.full? && should_open?
              @last_open_or_probed = @clock.timestamp
              @opened_at_request_number = most_recent_request_number
            end
          end
        end
      end

      private

      def open?
        @opened_at_request_number > 0
      end

      def should_open?
        raise NotImplementedError
      end

      def allow_probe_request?
        if open? && @clock.timestamp >= (@last_open_or_probed + @sleep_seconds)
          # makes sure that we allow only one probe request by extending sleep interval
          @last_open_or_probed = @clock.timestamp
          return true
        end
        false
      end
    end

  end
end
