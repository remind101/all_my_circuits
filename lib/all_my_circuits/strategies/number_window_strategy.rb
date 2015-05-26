module AllMyCircuits
  module Strategies

    class NumberWindowStrategy < AbstractWindowStrategy
      def initialize(failures_threshold:, **kwargs)
        @failures_threshold = failures_threshold
        super(**kwargs)
      end

      private

      def should_open?
        @window.count(:failed) >= @failures_threshold
      end
    end

  end
end
