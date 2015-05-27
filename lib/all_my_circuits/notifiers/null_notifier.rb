module AllMyCircuits
  module Notifiers

    class NullNotifier < AbstractNotifier
      def initialize(breaker_name, **kwargs)
      end

      def opened
      end

      def closed
      end
    end

  end
end
