module AllMyCircuits
  module Notifiers

    # Public: notifies some service about change of breaker's state.
    # For example, one could send a Librato metric whenever a circuit
    # breaker is opened or closed.
    #
    class AbstractNotifier
      def initialize(breaker_name, **kwargs)
        @breaker_name = breaker_name
      end

      # Public: called once the circuit is tripped open.
      #
      def opened
        raise NotImplementedError
      end

      # Public: called once the circuit is closed.
      #
      def closed
        raise NotImplementedError
      end
    end

  end
end
