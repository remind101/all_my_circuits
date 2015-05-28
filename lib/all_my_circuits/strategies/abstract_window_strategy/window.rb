module AllMyCircuits
  module Strategies
    class AbstractWindowStrategy

      class Window
        def initialize(number_of_events)
          number_of_events = Integer(number_of_events)
          unless number_of_events > 0
            raise ArgumentError, "window size must be a natural number"
          end
          @number_of_events = number_of_events
          reset!
        end

        def reset!
          @window = []
          @counters = Hash.new { |h, k| h[k] = 0 }
        end

        def <<(event)
          if full?
            event_to_decrement = @window.shift
            @counters[event_to_decrement] -= 1
          end
          @window.push(event)
          @counters[event] += 1
          self
        end

        def count(event = nil)
          event.nil? ? @window.length : @counters[event]
        end

        def full?
          @window.length == @number_of_events
        end
      end

    end
  end
end
