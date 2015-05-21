module AllMyCircuits
  class AbstractWindowStrategy
    def initialize(measure_window_seconds:, sleep_seconds:, clock: Clock)
      @measure_window_seconds = measure_window_seconds
      @sleep_seconds = sleep_seconds
      @clock = clock

      @open = false
      @last_open_or_probed = nil

      @window = Window.new(@measure_window_seconds, clock: @clock)
    end

    def allow_request?
      !open? || allow_probe_request?
    end

    def success
      if @open
        @open = false
        @last_open_or_probed = nil
        @window.reset!
      end
      @window << :succeeded
    end

    def error
      @window << :failed
    end

    private

    def open?
      return true if @open

      if @window.full? && should_open?
        @open = true
        @last_open_or_probed = @clock.timestamp
        return true
      end
      false
    end

    def should_open?
      raise NotImplementedError
    end

    def allow_probe_request?
      if @open && @clock.timestamp >= (@last_open_or_probed + @sleep_seconds)
        @last_open_or_probed = @clock.timestamp
        return true
      end
      false
    end
  end

  class PercentageWindowStrategy < AbstractWindowStrategy
    def initialize(failure_rate_percent_threshold:, volume_threshold:, **kwargs)
      @failure_rate_percent_threshold = failure_rate_percent_threshold
      @volume_threshold = volume_threshold
      super(**kwargs)
    end

    private

    def should_open?
      unless @window.count >= @volume_threshold
        return false
      end
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
    def initialize(duration_seconds, clock: Clock)
      @window_duration_seconds = duration_seconds
      @clock = clock
      reset!
    end

    def reset!
      @events = []
      @initialized_at_seconds = @clock.timestamp
    end

    def <<(event_type)
      @events << Event.new(event_type, @clock.timestamp)
      @events.keep_if { |e| within?(e) }
      self
    end

    def count(event_type = nil)
      if event_type
        @events.count { |e| e.type == event_type && within?(e) }
      else
        @events.count { |e| within?(e) }
      end
    end

    def full?
      @clock.timestamp >= (@initialized_at_seconds + @window_duration_seconds)
    end

    private

    def within?(event)
      beginning = @clock.timestamp - @window_duration_seconds
      event.timestamp > beginning
    end
  end

  Event = Struct.new(:type, :timestamp)

  class Breaker
    # TODO concurrency

    STRATEGIES = {
      nil                     => PercentageWindowStrategy,
      :percentage_over_window => PercentageWindowStrategy,
      :number_over_window    => NumberWindowStrategy
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
