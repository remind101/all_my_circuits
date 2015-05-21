module AllMyCircuits
  class PercentageOverWindow
    attr_reader :measure_window_seconds, :threshold_percent

    def initialize(measure_window_seconds:, threshold_percent:)
      @measure_window_seconds = measure_window_seconds
      @threshold_percent = threshold_percent
    end
  end

  class Breaker
    # TODO sub-second resolution
    # TODO concurrency

    def initialize(name:, strategy:, sleep_window_seconds:, clock: Time)
      @name = name.dup
      @sleep_window_seconds = sleep_window_seconds
      @clock = clock
      strategy.delete(:name)
      @strategy = PercentageOverWindow.new(**strategy)

      @open = false
      @last_open_or_probed = nil

      @errors_in_window = []
      @succeeded_requests_in_window = []
      @window_initialized_at = current_time
    end

    def run
      unless allow_request?
        raise BreakerOpen, @name
      end

      begin
        yield
        success
      rescue
        error
        raise
      end
    end

    private

    def allow_request?
      !open? || allow_probe_request?
    end

    def open?
      return true if @open

      if requests_in_window > 0 && (@window_initialized_at + @strategy.measure_window_seconds) <= current_time
        failure_percentage = ((errors_in_window.to_f / requests_in_window) * 100).ceil
        if failure_percentage >= @strategy.threshold_percent
          @open = true
          @last_open_or_probed = current_time
          return true
        end
      end
      false
    end

    def errors_in_window
      # memory leak
      @errors_in_window.select { |e| e > current_time - @sleep_window_seconds }.count
    end

    def requests_in_window
      # memory leak
      @succeeded_requests_in_window.select { |e| e > current_time - @strategy.measure_window_seconds }.count +
        @errors_in_window.count
    end

    def allow_probe_request?
      if @open && current_time >= (@last_open_or_probed + @sleep_window_seconds)
        #side effect prolonging open window
        @last_open_or_probed = current_time
        return true
      end
      false
    end

    def success
      @succeeded_requests_in_window.push current_time
      if @open
        @open = false
        @last_open_or_probed = nil
      end
    end

    def error
      @errors_in_window.push current_time
    end

    def current_time
      @clock.now.to_f
    end
  end
end
