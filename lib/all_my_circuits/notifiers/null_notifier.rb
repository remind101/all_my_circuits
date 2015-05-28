module AllMyCircuits
  module Notifiers

    # Public: no-op implementation of AbstractNotifier.
    #
    class NullNotifier < AbstractNotifier
      def initialize(*args, **kwargs)
      end

      def opened
      end

      def closed
      end
    end

  end
end
