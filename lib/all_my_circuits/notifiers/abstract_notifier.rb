module AllMyCircuits
  module Notifiers

    # Public: notifies some service about change of breaker's state.
    # For example, one could send a Librato metric whenever a circuit
    # breaker is opened or closed.
    #
    # To add a new notifier, subclass AllMyCircuits::Notifiers::AbstractNotifer,
    # then register it:
    #
    #   class MyNotifier < AllMyCircuits::Notifiers::AbstractNotifier
    #     AllMyCircuits::Breaker::NOTIFIERS[:my_notifier] = self
    #   end
    #
    class AbstractNotifier
      def initialize(breaker_name, **kwargs)
        @breaker_name = breaker_name
      end

      def opened
        raise NotImplementedError
      end

      def closed
        raise NotImplementedError
      end
    end

  end
end
