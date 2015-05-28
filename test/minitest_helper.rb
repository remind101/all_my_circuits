$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "bundler/setup"
require "all_my_circuits"

require "minitest/autorun"

class AllMyCircuitsTC < Minitest::Test
  class SimulatedFailure < StandardError; end

  class FakeClock
    def initialize
      @time = 0
    end

    def timestamp
      @time
    end

    def advance(seconds = 1)
      @time += seconds
    end
  end

  class FakeStrategy
    def initialize(should_open:, error: proc {}, success: proc {}, opened: proc {}, closed: proc {}, **kwargs)
      @should_open = should_open
      @error = error
      @success = success
      @opened = opened
      @closed = closed
    end

    def should_open?
      @should_open.call
    end

    def error
      @error.call
    end

    def success
      @success.call
    end

    def opened
      @opened.call
    end

    def closed
      @closed.call
    end
  end

  class FakeNotifier
    def initialize(breaker_name, opened: proc {}, closed: proc {}, **kwargs)
      @name = breaker_name
      @opened = opened
      @closed = closed
    end

    def opened
      @opened.call(@name)
    end

    def closed
      @closed.call(@name)
    end
  end

  def self.test(name, &block)
    block ||= proc { skip }
    define_method("test_#{name}", &block)
  end

  def self.xtest(name, &block)
    test(name)
  end
end
