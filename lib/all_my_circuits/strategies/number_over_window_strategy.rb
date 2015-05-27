module AllMyCircuits
  module Strategies

    # Public: opens the circuit whenever failures threshold is reached
    # within the window. Threshold is represented by absolute number of
    # failures within the window.
    #
    class NumberOverWindowStrategy < AbstractWindowStrategy

      # Public: initializes a new instance.
      #
      # Options
      #
      #   requests_window    - number of consecutive requests tracked by the window.
      #   failures_threshold - number of failures within the window after which
      #                        the circuit is tripped open.
      #
      def initialize(failures_threshold:, **kwargs)
        @failures_threshold = failures_threshold
        super(**kwargs)
      end

      def should_open?
        return unless @window.full?

        failures = @window.count(:failed)
        failures >= @failures_threshold
      end
    end

  end
end
