module AllMyCircuits
  module Strategies

    # Public: opens the circuit whenever failures threshold is reached
    # within the window. Threshold is represented by a percentage of
    # failures within the window.
    #
    class PercentageOverWindowStrategy < AbstractWindowStrategy

      # Public: initializes a new instance.
      #
      # Options
      #
      #   requests_window                - number of consecutive requests tracked by the window.
      #   failure_rate_percent_threshold - percent rate of failures within the window after which
      #                                    the circuit is tripped open.
      #
      def initialize(failure_rate_percent_threshold:, **kwargs)
        @failure_rate_percent_threshold = failure_rate_percent_threshold
        super(**kwargs)
      end

      def should_open?
        return false unless @window.full?

        failure_rate_percent = ((@window.count(:failed).to_f / @window.count) * 100).ceil
        failure_rate_percent >= @failure_rate_percent_threshold
      end
    end

  end
end
