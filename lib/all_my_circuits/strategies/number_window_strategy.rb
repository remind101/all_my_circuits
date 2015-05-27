module AllMyCircuits
  module Strategies

    class NumberWindowStrategy < AbstractWindowStrategy
      def initialize(failures_threshold:, **kwargs)
        @failures_threshold = failures_threshold
        super(**kwargs)
      end

      def should_open?
        @window.full? && @window.count(:failed) >= @failures_threshold
      end
    end

  end
end
