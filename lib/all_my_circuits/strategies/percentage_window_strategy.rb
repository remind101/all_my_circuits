module AllMyCircuits
  module Strategies

    class PercentageWindowStrategy < AbstractWindowStrategy
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
