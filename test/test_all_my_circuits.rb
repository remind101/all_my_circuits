require 'minitest_helper'
require 'all_my_circuits'

class TestAllMyCircuits < AllMyCircuitsTC
  test "has version number" do
    refute_nil ::AllMyCircuits::VERSION
  end

  class FakeClock
    def initialize
      @seconds = 1
    end

    def now
      @seconds
    end

    def advance(by_seconds = 1)
      @seconds += by_seconds
    end
  end

  def setup
    super
    @fake_clock = FakeClock.new
  end

  test "does something useful" do
    breaker = AllMyCircuits::Breaker.new(
      name: "test service circuit breaker",
      strategy: {
        name: :percentage_over_window,
        measure_window_seconds: 4,
        threshold_percent: 50
      },
      sleep_window_seconds: 4,
      clock: @fake_clock
    )

    assert_equal :succeeded, run_through_breaker(breaker) { :success }
    @fake_clock.advance
    assert_equal :failed, run_through_breaker(breaker) { raise "massive fail" }
    @fake_clock.advance
    assert_equal :succeeded, run_through_breaker(breaker) { :success }
    @fake_clock.advance
    assert_equal :failed, run_through_breaker(breaker) { raise "another massive fail that trips the breaker" }
    @fake_clock.advance

    4.times do
      assert_equal :skipped, run_through_breaker(breaker) { fail "this does not happen" }
      @fake_clock.advance
    end

    assert_equal :succeeded, run_through_breaker(breaker) { :success }
    @fake_clock.advance
    assert_equal :failed, run_through_breaker(breaker) { raise "failure that does not trip the breaker" }
    @fake_clock.advance
    assert_equal :succeeded, run_through_breaker(breaker) { :success }
    @fake_clock.advance(10)
  end

  test "trips the breaker again if first call after reenable_after interval has failed" do
    breaker = AllMyCircuits::Breaker.new(
      name: "test service circuit breaker",
      strategy: {
        name: :percentage_over_window,
        measure_window_seconds: 4,
        threshold_percent: 50
      },
      sleep_window_seconds: 4,
      clock: @fake_clock
    )

    assert_equal :succeeded, run_through_breaker(breaker) { :success }
    @fake_clock.advance
    assert_equal :failed, run_through_breaker(breaker) { raise "massive fail" }
    @fake_clock.advance
    assert_equal :succeeded, run_through_breaker(breaker) { :success }
    @fake_clock.advance
    assert_equal :failed, run_through_breaker(breaker) { raise "another massive fail that trips the breaker" }
    @fake_clock.advance

    4.times do
      assert_equal :skipped, run_through_breaker(breaker) { refute "this does not happen" }
      @fake_clock.advance
    end

    assert_equal :failed, run_through_breaker(breaker) { raise "trips the breaker again" }
    @fake_clock.advance
    assert_equal :skipped, run_through_breaker(breaker) { fail "this does not happen" }
  end

  def run_through_breaker(breaker)
    begin
      breaker.run do
        yield
      end
      :succeeded
    rescue AllMyCircuits::BreakerOpen
      :skipped
    rescue
      :failed
    end
  end

  # make it global within process
end
