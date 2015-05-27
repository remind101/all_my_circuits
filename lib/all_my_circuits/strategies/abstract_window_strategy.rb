module AllMyCircuits
  module Strategies

    class AbstractWindowStrategy < AbstractStrategy
      autoload :Window, "all_my_circuits/strategies/abstract_window_strategy/window"

      def initialize(requests_window:)
        @requests_window = requests_window
        @window = Window.new(@requests_window)
      end

      def success
        @window << :succeeded
      end

      def error
        @window << :failed
      end

      def opened
      end

      def closed
        @window.reset!
      end

      def should_open?
        raise NotImplementedError
      end
    end

  end
end
