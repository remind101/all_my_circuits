require "minitest_helper"
require "all_my_circuits"

class TestAllMyCircuits < AllMyCircuitsTC
  test "has version number" do
    refute_nil ::AllMyCircuits::VERSION
  end

  class FakeClock
    def initialize
      @seconds = 1
    end

    def timestamp
      @seconds
    end

    def advance(by_seconds = 1)
      @seconds += by_seconds
    end
  end

  def setup
    super
    @fake_clock = FakeClock.new
    @breaker = AllMyCircuits::Breaker.new(
      name: "test service circuit breaker",
      strategy: {
        name: :percentage_over_window,
        requests_window: 4,
        failure_rate_percent_threshold: 50,
        sleep_seconds: 4,
        clock: @fake_clock
      }
    )
  end

  test "trips the breaker and recovers upon first successful request" do
    assert_equal :succeeded, run_through_breaker { :success }
    assert_equal :failed, run_through_breaker { raise "massive fail" }
    assert_equal :succeeded, run_through_breaker { :success }
    assert_equal :failed, run_through_breaker { raise "another massive fail that trips the breaker" }

    4.times do
      assert_equal :skipped, run_through_breaker { assert false, "this does not happen" }
      @fake_clock.advance
    end

    assert_equal :succeeded, run_through_breaker { :success }
    assert_equal :failed, run_through_breaker { raise "failure that does not trip the breaker" }
    assert_equal :succeeded, run_through_breaker { :success }
  end

  test "trips the breaker again if first call after reenable_after interval has failed" do
    assert_equal :succeeded, run_through_breaker { :success }
    assert_equal :failed, run_through_breaker { raise "massive fail" }
    assert_equal :succeeded, run_through_breaker { :success }
    assert_equal :failed, run_through_breaker { raise "another massive fail that trips the breaker" }

    4.times do
      assert_equal :skipped, run_through_breaker { assert false, "this does not happen" }
      @fake_clock.advance
    end

    assert_equal :failed, run_through_breaker { raise "trips the breaker again" }
    assert_equal :skipped, run_through_breaker { fail "this does not happen" }
  end

  def run_through_breaker
    begin
      @breaker.run do
        yield
      end
      :succeeded
    rescue AllMyCircuits::BreakerOpen
      :skipped
    rescue
      # p $!, $!.backtrace.first(2).join(",")
      :failed
    end
  end
end
