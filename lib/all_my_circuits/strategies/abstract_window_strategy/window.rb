module AllMyCircuits
  module Strategies
    class AbstractWindowStrategy

      class Window
        def initialize(number_of_events)
          @number_of_events = number_of_events
          reset!
        end

        def reset!
          @events = []
        end

        def <<(event_type)
          @events << event_type
          @events.shift if @events.count > @number_of_events
          self
        end

        def count(event_type = nil)
          if event_type
            @events.count { |e| e == event_type }
          else
            @events.count
          end
        end

        def full?
          @events.count == @number_of_events
        end
      end

    end
  end
end
