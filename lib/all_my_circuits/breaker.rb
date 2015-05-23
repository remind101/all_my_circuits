require "concurrent/atomic"

module AllMyCircuits
  class AbstractWindowStrategy
    def initialize(requests_window:, sleep_seconds:, clock: Clock)
      @requests_window = requests_window
      @sleep_seconds = sleep_seconds
      @clock = clock

      @open = false
      @last_open_or_probed = nil

      @window = Window.new(@requests_window)

      @state_mtx = Mutex.new
    end

    def allow_request?
      @state_mtx.synchronize do
        !open? || allow_probe_request?
      end
    end

    def success
      @state_mtx.synchronize do
        if @open
          @open = false
          @last_open_or_probed = 0
          @window.reset!
        end
        @window << :succeeded
      end
    end

    def error
      @state_mtx.synchronize do
        @window << :failed
        if @window.full? && should_open?
          @open = true
          @last_open_or_probed = @clock.timestamp
        end
      end
    end

    private

    def open?
      @open
    end

    def should_open?
      raise NotImplementedError
    end

    def allow_probe_request?
      if open? && @clock.timestamp >= (@last_open_or_probed + @sleep_seconds)
        @last_open_or_probed = @clock.timestamp
        return true
      end
      false
    end
  end

  class PercentageWindowStrategy < AbstractWindowStrategy
    def initialize(failure_rate_percent_threshold:, **kwargs)
      @failure_rate_percent_threshold = failure_rate_percent_threshold
      super(**kwargs)
    end

    private

    def should_open?
      failure_rate_percent = ((@window.count(:failed).to_f / @window.count) * 100).ceil
      failure_rate_percent >= @failure_rate_percent_threshold
    end
  end

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

  # A 1-second resolution clock
  class Clock
    def self.timestamp
      Time.now.to_i
    end
  end

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

  class Breaker
    STRATEGIES = {
      nil                     => PercentageWindowStrategy,
      :percentage_over_window => PercentageWindowStrategy,
      :number_over_window     => NumberWindowStrategy
    }

    def initialize(name:, strategy:)
      @name = name.dup

      begin
        strategy_name = strategy.delete(:name)
        @strategy = STRATEGIES.fetch(strategy_name).new(**strategy)
      rescue KeyError
        raise ArgumentError, "Unknown circuit breaker strategy: #{strategy_name}"
      end
    end

    def run
      unless @strategy.allow_request?
        raise BreakerOpen, @name
      end

      begin
        yield
        @strategy.success
      rescue
        @strategy.error
        raise
      end
    end
  end

end
