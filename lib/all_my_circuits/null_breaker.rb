module AllMyCircuits

  # Public: no-op circuit breaker implementation, useful for testing
  #
  class NullBreaker
    attr_reader :name
    attr_accessor :closed

    def initialize(name:, closed:)
      @name = name
      @closed = closed
    end

    def run
      if @closed
        yield
      else
        raise AllMyCircuits::BreakerOpen, @name
      end
    end
  end

end
